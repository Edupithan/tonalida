// auth/hook-post-auth.ts
// Trigger pós-registro: cria o perfil na tabela profiles
// Chamado via webhook do Supabase Auth

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { supabaseAdmin, corsHeaders } from "../_shared/supabase-client.ts";
import type { TipoPerfil } from "../_shared/types.ts";

interface AuthHookPayload {
  type: "INSERT";
  table: "users";
  record: {
    id: string;
    email: string;
    raw_user_meta_data: {
      tipo?: TipoPerfil;
      nome_completo?: string;
      telefone?: string;
      full_name?: string; // Google OAuth
    };
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: AuthHookPayload = await req.json();
    const { id, email, raw_user_meta_data } = payload.record;

    const tipo: TipoPerfil = raw_user_meta_data.tipo ?? "cliente";
    const nome_completo =
      raw_user_meta_data.nome_completo ||
      raw_user_meta_data.full_name ||
      email.split("@")[0];
    const telefone = raw_user_meta_data.telefone ?? "";

    // Verificar se perfil já existe (idempotência)
    const { data: existing } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("id", id)
      .single();

    if (existing) {
      return new Response(JSON.stringify({ message: "Perfil já existe" }), {
        headers: corsHeaders,
      });
    }

    // Criar perfil
    const { error: profileError } = await supabaseAdmin
      .from("profiles")
      .insert({
        id,
        tipo,
        nome_completo,
        email,
        telefone,
        status: "ativo",
      });

    if (profileError) {
      console.error("Erro ao criar profile:", profileError);
      return new Response(JSON.stringify({ error: profileError.message }), {
        status: 500,
        headers: corsHeaders,
      });
    }

    // Se profissional, criar registro básico em profissionais
    if (tipo === "profissional") {
      const { error: profError } = await supabaseAdmin
        .from("profissionais")
        .insert({
          profile_id: id,
          verificado: false,
          destaque: false,
          media_avaliacao: 0,
          total_avaliacoes: 0,
          total_servicos: 0,
        });

      if (profError) {
        console.error("Erro ao criar profissional:", profError);
      }
    }

    console.log(`Perfil criado com sucesso: ${id} (${tipo})`);
    return new Response(
      JSON.stringify({ success: true, id, tipo }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("Hook post-auth erro:", error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: corsHeaders,
    });
  }
});
