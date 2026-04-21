// push/send-notification.ts
// POST /push/send-notification
// Envia notificação push via FCM (uso interno entre Edge Functions)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/supabase-client.ts";
import { sendPushNotification } from "../_shared/fcm.ts";
import type { PushNotificationPayload } from "../_shared/types.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Esta função é interna - valida apenas o service role key
  const authHeader = req.headers.get("Authorization");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!authHeader || !authHeader.includes(serviceKey ?? "")) {
    return new Response(
      JSON.stringify({ error: "Não autorizado" }),
      { status: 401, headers: corsHeaders }
    );
  }

  try {
    const payload: PushNotificationPayload = await req.json();

    if (!payload.tokens?.length || !payload.title || !payload.body) {
      return new Response(
        JSON.stringify({ error: "tokens, title e body são obrigatórios" }),
        { status: 400, headers: corsHeaders }
      );
    }

    await sendPushNotification(payload);

    return new Response(
      JSON.stringify({ success: true, recipients: payload.tokens.length }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("Erro ao enviar notificação:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
