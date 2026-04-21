// chat/enviar-mensagem.ts
// POST /chat/mensagens
// Envia mensagem, atualiza conversa e notifica destinatário

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { supabaseAdmin, getUserFromRequest, corsHeaders } from "../_shared/supabase-client.ts";
import { sendPushNotification } from "../_shared/fcm.ts";
import type { MensagemPayload } from "../_shared/types.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let user;
  try {
    user = await getUserFromRequest(req);
  } catch (resp) {
    return resp as Response;
  }

  try {
    const body: MensagemPayload = await req.json();
    const { conversa_id, conteudo, tipo = "texto", metadata } = body;

    if (!conversa_id || !conteudo?.trim()) {
      return new Response(
        JSON.stringify({ error: "conversa_id e conteudo são obrigatórios" }),
        { status: 400, headers: corsHeaders }
      );
    }

    if (conteudo.length > 4000) {
      return new Response(
        JSON.stringify({ error: "Mensagem muito longa (máx 4000 caracteres)" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Verificar se usuário participa da conversa
    const { data: conversa, error: convError } = await supabaseAdmin
      .from("conversas")
      .select("id, cliente_id, profissional_id, status")
      .eq("id", conversa_id)
      .single();

    if (convError || !conversa) {
      return new Response(
        JSON.stringify({ error: "Conversa não encontrada" }),
        { status: 404, headers: corsHeaders }
      );
    }

    if (conversa.cliente_id !== user.id && conversa.profissional_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Não autorizado nesta conversa" }),
        { status: 403, headers: corsHeaders }
      );
    }

    if (conversa.status === "bloqueado") {
      return new Response(
        JSON.stringify({ error: "Esta conversa está bloqueada" }),
        { status: 403, headers: corsHeaders }
      );
    }

    // Inserir mensagem (imutável: apenas INSERT)
    const { data: mensagem, error: msgError } = await supabaseAdmin
      .from("mensagens")
      .insert({
        conversa_id,
        remetente_id: user.id,
        conteudo,
        tipo,
        metadata: metadata ?? null,
        lida: false,
      })
      .select()
      .single();

    if (msgError) {
      console.error("Erro ao inserir mensagem:", msgError);
      return new Response(
        JSON.stringify({ error: "Erro ao enviar mensagem" }),
        { status: 500, headers: corsHeaders }
      );
    }

    // Atualizar última mensagem na conversa
    await supabaseAdmin
      .from("conversas")
      .update({
        ultima_mensagem: tipo === "texto" ? conteudo : `[${tipo}]`,
        ultima_mensagem_at: new Date().toISOString(),
      })
      .eq("id", conversa_id);

    // Determinar destinatário
    const destinatario_id =
      conversa.cliente_id === user.id
        ? conversa.profissional_id
        : conversa.cliente_id;

    // Buscar nome do remetente
    const { data: remetente } = await supabaseAdmin
      .from("profiles")
      .select("nome_completo")
      .eq("id", user.id)
      .single();

    const nomeRemetente = remetente?.nome_completo ?? "Alguém";

    // Criar notificação in-app
    await supabaseAdmin.from("notificacoes").insert({
      user_id: destinatario_id,
      tipo: "nova_mensagem",
      titulo: `Nova mensagem de ${nomeRemetente}`,
      corpo: tipo === "texto" ? conteudo.substring(0, 100) : `[${tipo}]`,
      dados: { conversa_id, remetente_id: user.id, mensagem_id: mensagem.id },
    });

    // Enviar push notification
    const { data: tokens } = await supabaseAdmin
      .from("device_tokens")
      .select("token")
      .eq("user_id", destinatario_id)
      .eq("ativo", true);

    if (tokens && tokens.length > 0) {
      try {
        await sendPushNotification({
          tokens: tokens.map((t: { token: string }) => t.token),
          title: `Nova mensagem de ${nomeRemetente}`,
          body: tipo === "texto" ? conteudo.substring(0, 100) : `[${tipo}]`,
          data: { conversa_id, tipo: "chat", mensagem_id: mensagem.id },
        });

        // Atualizar last_used dos tokens
        await supabaseAdmin
          .from("device_tokens")
          .update({ last_used: new Date().toISOString() })
          .in("token", tokens.map((t: { token: string }) => t.token));
      } catch (pushError) {
        console.warn("Erro ao enviar push:", pushError);
        // Não falha a requisição por erro de push
      }
    }

    return new Response(
      JSON.stringify({ success: true, mensagem }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("Erro ao enviar mensagem:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
