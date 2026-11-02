import { createClient } from "@supabase/supabase-js";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
});
// Signed URLs are bearer capabilities, valid for at most 60 seconds. Never log them.
const lifetimeSeconds = 60;
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed." });
  const url = Deno.env.get("SUPABASE_URL");
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !secret || !anon) return json(503, { error: "Photos are unavailable. Try again." });
  const token = req.headers.get("Authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (!token || token.length > 8192) return json(401, { error: "Sign in to view this photo." });
  try {
    if (!req.headers.get("Content-Type")?.toLowerCase().startsWith("application/json")) return json(415, { error: "A JSON request is required." });
    if (Number(req.headers.get("Content-Length")) > 512) return json(413, { error: "Request too large." });
    const reader = req.body?.getReader();
    if (!reader) return json(400, { error: "Invalid photo request." });
    const bytes = new Uint8Array(512);
    let length = 0;
    try {
      while (true) {
        const chunk = await reader.read();
        if (chunk.done) break;
        if (length + chunk.value.length > 512) { await reader.cancel(); return json(413, { error: "Request too large." }); }
        bytes.set(chunk.value, length); length += chunk.value.length;
      }
    } finally { reader.releaseLock(); }
    let revision: string;
    try {
      const body = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(0, length)));
      if (!body || typeof body.revision_id !== "string" || !uuid.test(body.revision_id)) throw new Error();
      revision = body.revision_id;
    } catch { return json(400, { error: "Invalid photo request." }); }
    const admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
    const user = createClient(url, anon, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const identity = await admin.auth.getUser(token);
    if (identity.error || !identity.data.user) return json(401, { error: "Sign in to view this photo." });
    const access = await user.rpc("toti_media_access", { p_revision: revision });
    if (access.error || typeof access.data?.object_path !== "string") return json(403, { error: "This photo is unavailable." });
    const issuedAt = Date.now();
    const signed = await admin.storage.from("toti-media").createSignedUrl(access.data.object_path, lifetimeSeconds);
    if (signed.error || !signed.data?.signedUrl) throw new Error("Signing unavailable");
    // Recheck live session, current attachment, account and blocks after signing.
    const current = await user.rpc("toti_media_access", { p_revision: revision });
    if (current.error || current.data?.object_path !== access.data.object_path) return json(403, { error: "This photo is unavailable." });
    return json(200, { signed_url: signed.data.signedUrl, expires_at: new Date(issuedAt + lifetimeSeconds * 1000).toISOString() });
  } catch { return json(503, { error: "This photo could not load. Try again." }); }
});
