import { createClient } from "@supabase/supabase-js";
import jpeg from "jpeg-js";

// Never log request bodies, identities, JPEGs, paths, tokens or signed URLs.
const MAX_BYTES = 1_048_576;
const MAX_REQUEST = 1_400_000;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
});
class RequestError extends Error {
  constructor(readonly status: number, message: string) { super(message); }
}
async function boundedJSON(req: Request): Promise<Record<string, unknown>> {
  if (!req.headers.get("Content-Type")?.toLowerCase().startsWith("application/json")) {
    throw new RequestError(415, "A JSON request is required.");
  }
  const length = Number(req.headers.get("Content-Length"));
  if (length > MAX_REQUEST) throw new RequestError(413, "The selected photo is too large.");
  const reader = req.body?.getReader();
  if (!reader) throw new RequestError(400, "Invalid photo request.");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > MAX_REQUEST) {
        await reader.cancel();
        throw new RequestError(413, "The selected photo is too large.");
      }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try {
    const body = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error();
    return body;
  } catch { throw new RequestError(400, "Invalid photo request."); }
}

// This preflight only bounds work; acceptance always requires complete pixel decoding.
function dimensions(bytes: Uint8Array): { width: number; height: number } {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8 ||
      bytes[bytes.length - 2] !== 0xff || bytes[bytes.length - 1] !== 0xd9) throw new Error();
  let at = 2;
  while (at + 3 < bytes.length) {
    if (bytes[at++] !== 0xff) throw new Error();
    while (bytes[at] === 0xff) at++;
    const marker = bytes[at++];
    if (marker === 0xda || marker === 0xd9 || marker === 0x00 || marker === 0xd8) throw new Error();
    const length = bytes[at] * 256 + bytes[at + 1];
    if (length < 2 || at + length > bytes.length) throw new Error();
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      if (length < 8 || bytes[at + 2] !== 8) throw new Error();
      const height = bytes[at + 3] * 256 + bytes[at + 4];
      const width = bytes[at + 5] * 256 + bytes[at + 6];
      if (width < 1 || height < 1 || width > 2048 || height > 2048 || width * height > 4_000_000) throw new Error();
      return { width, height };
    }
    at += length;
  }
  throw new Error();
}
async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed." });
  const url = Deno.env.get("SUPABASE_URL");
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !secret || !anon) return json(503, { error: "Photo uploads are unavailable. Try again." });
  const token = req.headers.get("Authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (!token || token.length > 8192) return json(401, { error: "Sign in to upload a photo." });
  try {
    const admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
    const user = createClient(url, anon, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const identity = await admin.auth.getUser(token);
    if (identity.error || !identity.data.user) return json(401, { error: "Sign in to upload a photo." });
    const context = await user.rpc("toti_media_context");
    if (context.error || context.data?.actor_id !== identity.data.user.id || !uuid.test(context.data?.session_id ?? "")) {
      return json(401, { error: "Your session has expired. Sign in again." });
    }
    const body = await boundedJSON(req);
    if (typeof body.revision_id !== "string" || !uuid.test(body.revision_id) ||
        typeof body.entity_id !== "string" || !uuid.test(body.entity_id) ||
        typeof body.kind !== "string" || !["avatar", "post"].includes(body.kind) || typeof body.jpeg_base64 !== "string") {
      return json(400, { error: "Invalid photo request." });
    }
    if (body.jpeg_base64.length > Math.ceil(MAX_BYTES / 3) * 4) return json(413, { error: "The selected photo is too large." });
    let source: Uint8Array;
    let normalized: Uint8Array;
    let width: number;
    let height: number;
    try {
      if (body.jpeg_base64.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(body.jpeg_base64)) throw new Error();
      const decoded = atob(body.jpeg_base64);
      if (decoded.length > MAX_BYTES || decoded.length < 4) throw new Error();
      source = Uint8Array.from(decoded, (character) => character.charCodeAt(0));
      const expected = dimensions(source);
      const pixels = jpeg.decode(source, {
        useTArray: true, formatAsRGBA: true, tolerantDecoding: false,
        maxResolutionInMP: 4, maxMemoryUsageInMB: 64,
      });
      width = pixels.width; height = pixels.height;
      if (width !== expected.width || height !== expected.height || pixels.data.length !== width * height * 4) throw new Error();
      // Pass only decoded pixels: EXIF/GPS, ICC, comments and trailing payloads are not copied.
      normalized = new Uint8Array(jpeg.encode({ width, height, data: pixels.data }, 82).data);
      if (normalized.length > MAX_BYTES) throw new RequestError(422, "Choose a smaller photo and try again.");
    } catch (error) {
      if (error instanceof RequestError) throw error;
      return json(422, { error: "Choose a valid JPEG photo up to 2048 pixels per side." });
    }
    const normalizedSHA = await sha256(normalized);
    const actor = context.data.actor_id;
    const session = context.data.session_id;
    const reservation = await admin.rpc("toti_media_reserve", {
      p_actor: actor, p_session: session, p_revision: body.revision_id, p_kind: body.kind,
      p_entity: body.entity_id, p_source_sha256: await sha256(source), p_sha256: normalizedSHA,
      p_width: width, p_height: height, p_byte_size: normalized.length,
    });
    if (reservation.error) return json(409, { error: "This photo could not be accepted. Keep your selection and try again." });
    const path = reservation.data?.object_path;
    if (typeof path !== "string" || path !== `${actor}/${body.revision_id.toLowerCase()}/${normalizedSHA}.jpg`) {
      throw new Error("Invalid reservation");
    }
    if (reservation.data.upload_state !== "ready") {
      const uploaded = await user.storage.from("toti-media").upload(path, normalized, {
        contentType: "image/jpeg", cacheControl: "0", upsert: false,
      });
      // A concurrent/lost response may already have stored the immutable bytes.
      // The read-back below decides whether any error is safely recoverable.
      void uploaded;
    }
    // Always verify stored bytes, even after success. A caller can race its own
    // reserved-path INSERT, but invalid bytes must never become a ready revision.
    const existing = await admin.storage.from("toti-media").download(path);
    if (existing.error || !existing.data || existing.data.size !== normalized.length ||
        await sha256(new Uint8Array(await existing.data.arrayBuffer())) !== normalizedSHA) throw new Error("Upload incomplete");
    const finished = await admin.rpc("toti_media_finalize", {
      p_actor: actor, p_session: session, p_revision: body.revision_id,
    });
    if (finished.error) throw new Error("Upload finalization pending");
    return json(200, finished.data);
  } catch (error) {
    if (error instanceof RequestError) return json(error.status, { error: error.message });
    return json(503, { error: "The photo upload could not finish. Keep your selection and try again." });
  }
});
