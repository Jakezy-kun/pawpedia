// ============================================================================
// delete-account
// ============================================================================
// A Flutter client cannot delete its own auth user: that needs the
// service_role key, which must never ship inside an app bundle. This function
// holds that key server-side, verifies the caller's own JWT, and deletes only
// the user that JWT belongs to.
//
// profiles and favorites disappear on their own via ON DELETE CASCADE.
//
// Deploy:
//   supabase functions deploy delete-account
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected by the platform.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("delete-account: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return json({ error: "Server is not configured correctly." }, 500);
  }

  // 1. Read the caller's JWT.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return json({ error: "Authorization header is missing." }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 2. Verify it and extract the user id. getUser(token) validates the
  //    signature and expiry against the project, so a forged or stale token
  //    cannot get past this point.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    return json({ error: "Your session is no longer valid. Please log in again." }, 401);
  }

  const userId = userData.user.id;

  // 3. Delete the user this token belongs to — never an id supplied by the
  //    request body, which the caller controls.
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error("delete-account: deleteUser failed", deleteError);
    return json({ error: "We couldn't delete your account. Please try again." }, 500);
  }

  // 4. profiles + favorites cascaded. Storage objects are not covered by the
  //    cascade, so clear the user's avatar folder explicitly.
  const { data: avatarFiles } = await admin.storage.from("avatars").list(userId);
  if (avatarFiles?.length) {
    await admin.storage
      .from("avatars")
      .remove(avatarFiles.map((f: { name: string }) => `${userId}/${f.name}`));
  }

  return json({ success: true }, 200);
});
