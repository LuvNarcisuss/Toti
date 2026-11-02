import { createClient } from "@supabase/supabase-js";

// Only the verified current user can request or resume their own deletion.
// No credentials, tokens, email addresses or storage paths are logged.
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
});
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key || !anon) return json(503, { error: "Account deletion is unavailable" });
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json(401, { error: "Authentication required" });
  const text = await req.text();
  if (text.length > 2048) return json(413, { error: "Request too large" });
  let body: { operation_id?: string };
  try {
    body = JSON.parse(text);
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("Invalid body");
  } catch { return json(400, { error: "Invalid request" }); }
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: identity, error: identityError } = await admin.auth.getUser(token);
  if (identityError || !identity.user) return json(401, { error: "Authentication required" });
  const accountID = identity.user.id;
  if (typeof body.operation_id !== "string" || !uuid.test(body.operation_id)) return json(400, { error: "An operation ID is required" });
  const readPlan = async () => {
    const { data, error } = await admin.rpc("toti_deletion_plan", { p_account_id: accountID });
    if (error) throw error;
    return data as { status: string; paths: string[]; attachment_paths?: string[] } | null;
  };
  let accepted = false;
  try {
    let plan = await readPlan();
    if (!plan) {
      const user = createClient(url, anon, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: `Bearer ${token}` } },
      });
      const { error } = await user.rpc("toti_mutate", {
        p_operation_id: body.operation_id, p_action: "account.delete", p_entity_id: accountID, p_payload: {},
      });
      if (error) return json(409, { error: "Deletion could not be accepted. Sign in and try again." });
      plan = await readPlan();
    }
    accepted = true;
    if (plan?.status === "complete") return json(200, { status: "complete" });
    {
      const { error } = await admin.auth.admin.signOut(token, "global");
      // A previously revoked session is harmless; user deletion below invalidates refresh state.
      if (error && ![401, 403, 404].includes(error.status ?? 0)) throw error;
    }
    // Bounded request work. Repeated owner calls resume the same durable job.
    // If Auth removal succeeds but final bookkeeping fails, reconcile in the trusted dashboard.
    for (let page = 0; page < 4; page++) {
      plan = await readPlan();
      if (!plan) throw new Error("Missing deletion job");
      if (plan.paths.length === 0 && !plan.attachment_paths?.length) break;
      if (plan.paths.some((path) => !path.startsWith(`${accountID}/`))) throw new Error("Invalid storage ownership");
      if (plan.paths.length) {
        const { error } = await admin.storage.from("toti-media").remove(plan.paths);
        if (error) throw error;
      }
      const attachments = plan.attachment_paths ?? [];
      if (attachments.some((path) => !path.startsWith(`${accountID}/`))) throw new Error("Invalid storage ownership");
      if (attachments.length) {
        const removed = await admin.storage.from("toti-chat-attachments").remove(attachments);
        if (removed.error) throw removed.error;
      }
    }
    plan = await readPlan();
    if (plan?.paths.length || plan?.attachment_paths?.length) return json(202, { status: "pending" });
    const { error } = await admin.auth.admin.deleteUser(accountID);
    if (error && error.status !== 404 && error.code !== "user_not_found") throw error;
    const completed = await admin.rpc("toti_deletion_complete", { p_account_id: accountID });
    if (completed.error) throw completed.error;
    return json(200, { status: "complete" });
  } catch {
    return accepted ? json(202, { status: "pending" }) : json(503, { error: "Account deletion is unavailable. Try again." });
  }
});
