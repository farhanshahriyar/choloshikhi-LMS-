import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

function muxHeaders() {
  const tokenId = Deno.env.get("MUX_TOKEN_ID");
  const tokenSecret = Deno.env.get("MUX_TOKEN_SECRET");
  if (!tokenId || !tokenSecret) throw new Error("Mux credentials not configured");
  return {
    Authorization: "Basic " + btoa(`${tokenId}:${tokenSecret}`),
    "Content-Type": "application/json",
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Auth check
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: claimsData, error: claimsError } = await supabase.auth.getClaims(token);
    if (claimsError || !claimsData?.claims) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify teacher role
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { data: isTeacher } = await serviceClient.rpc("has_role", {
      _user_id: claimsData.claims.sub,
      _role: "teacher",
    });
    if (!isTeacher) {
      return new Response(JSON.stringify({ error: "Forbidden: teacher role required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { action, ...params } = await req.json();

    // Action: create-upload — returns a direct upload URL
    if (action === "create-upload") {
      const res = await fetch("https://api.mux.com/video/v1/uploads", {
        method: "POST",
        headers: muxHeaders(),
        body: JSON.stringify({
          new_asset_settings: {
            playback_policy: ["public"],
            encoding_tier: "baseline",
          },
          cors_origin: "*",
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(`Mux API error [${res.status}]: ${JSON.stringify(data)}`);
      return new Response(JSON.stringify({ upload_id: data.data.id, upload_url: data.data.url }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Action: check-upload — get upload status and asset id
    if (action === "check-upload") {
      const { upload_id } = params;
      if (!upload_id) throw new Error("upload_id required");
      const res = await fetch(`https://api.mux.com/video/v1/uploads/${upload_id}`, {
        headers: muxHeaders(),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(`Mux API error [${res.status}]: ${JSON.stringify(data)}`);
      return new Response(
        JSON.stringify({
          status: data.data.status,
          asset_id: data.data.asset_id || null,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Action: get-asset — get asset status and playback id
    if (action === "get-asset") {
      const { asset_id } = params;
      if (!asset_id) throw new Error("asset_id required");
      const res = await fetch(`https://api.mux.com/video/v1/assets/${asset_id}`, {
        headers: muxHeaders(),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(`Mux API error [${res.status}]: ${JSON.stringify(data)}`);
      const playbackId = data.data.playback_ids?.[0]?.id || null;
      return new Response(
        JSON.stringify({
          status: data.data.status,
          playback_id: playbackId,
          asset_id: data.data.id,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Action: delete-asset
    if (action === "delete-asset") {
      const { asset_id } = params;
      if (!asset_id) throw new Error("asset_id required");
      const res = await fetch(`https://api.mux.com/video/v1/assets/${asset_id}`, {
        method: "DELETE",
        headers: muxHeaders(),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(`Mux API error [${res.status}]: ${JSON.stringify(data)}`);
      }
      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Unknown action" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    console.error("Mux video error:", error);
    const msg = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
