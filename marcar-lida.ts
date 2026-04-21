// chat/marcar-lida.ts
// POST /chat/marcar-lida
// Marca mensagens de uma conversa como lidas para o usuário autenticado

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { supabaseAdmin, getUserFromRequest, corsHeaders } from "../_shared/supabase-client.ts";

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
    const { conversa_id } = await req.json();

    if (!conversa_id) {
      return new Response(
        JSON.stringify({ error: "conversa_id é obrigatório" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Verificar participação
    const { data: conversa } = await supabaseAdmin
      .from("conversas")
      .select("cliente_id, profissional_id")
      .eq("id", conversa_id)
      .single();

    if (!conversa || (conversa.cliente_id !== user.id && conversa.profissional_id !== user.id)) {
      return new Response(
        JSON.stringify({ error: "Conversa não encontrada ou não autorizado" }),
        { status: 403, headers: corsHeaders }
      );
    }

    // Marcar como lidas todas as mensagens NÃO enviadas pelo próprio usuário
    // NOTA: Usamos service_role para contornar a restrição de imutabilidade do RLS
    // O campo "lida" é a única exceção permitida ao conceito de imutabilidade das mensagens
    const { error, count } = await supabaseAdmin
      .from("mensagens")
      .update({ lida: true })
      .eq("conversa_id", conversa_id)
      .neq("remetente_id", user.id)
      .eq("lida", false);

    if (error) {
      console.error("Erro ao marcar mensagens:", error);
      return new Response(
        JSON.stringify({ error: "Erro ao marcar mensagens como lidas" }),
        { status: 500, headers: corsHeaders }
      );
    }

    // Marcar notificações de nova_mensagem desta conversa como lidas
    await supabaseAdmin
      .from("notificacoes")
      .update({ lida: true })
      .eq("user_id", user.id)
      .eq("tipo", "nova_mensagem")
      .contains("dados", { conversa_id });

    return new Response(
      JSON.stringify({ success: true, mensagens_marcadas: count }),
      { headers: corsHeaders }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
