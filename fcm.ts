// _shared/fcm.ts
// Firebase Cloud Messaging - envio de push notifications

import type { PushNotificationPayload } from "./types.ts";

const FCM_URL = "https://fcm.googleapis.com/fcm/send";

export async function sendPushNotification(payload: PushNotificationPayload): Promise<void> {
  const serverKey = Deno.env.get("FIREBASE_SERVER_KEY");
  if (!serverKey) {
    console.error("FIREBASE_SERVER_KEY não configurado.");
    return;
  }

  const { tokens, title, body, data } = payload;
  if (!tokens || tokens.length === 0) return;

  // Enviar para múltiplos tokens (FCM multicast)
  const fcmPayload = {
    registration_ids: tokens,
    notification: {
      title,
      body,
      sound: "default",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    data: data ?? {},
    priority: "high",
    content_available: true,
  };

  const response = await fetch(FCM_URL, {
    method: "POST",
    headers: {
      "Authorization": `key=${serverKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(fcmPayload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("Erro ao enviar push FCM:", errorText);
    throw new Error(`FCM error: ${response.status} - ${errorText}`);
  }

  const result = await response.json();

  // Log de tokens inválidos para limpeza futura
  if (result.failure > 0 && result.results) {
    const invalidTokens: string[] = [];
    result.results.forEach((r: { error?: string }, i: number) => {
      if (r.error === "InvalidRegistration" || r.error === "NotRegistered") {
        invalidTokens.push(tokens[i]);
      }
    });
    if (invalidTokens.length > 0) {
      console.warn("Tokens FCM inválidos detectados:", invalidTokens);
    }
  }

  console.log(`Push enviado: sucesso=${result.success}, falha=${result.failure}`);
}
