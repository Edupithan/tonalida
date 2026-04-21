// busca/profissionais.ts
// GET /busca/profissionais?filtros
// Busca profissionais com filtros, paginação e ordenação

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { supabaseAdmin, corsHeaders } from "../_shared/supabase-client.ts";
import type { BuscaFiltros } from "../_shared/types.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { searchParams } = new URL(req.url);

    const filtros: BuscaFiltros = {
      categoria: searchParams.get("categoria") ?? undefined,
      cidade: searchParams.get("cidade") ?? undefined,
      min_avaliacao: parseFloat(searchParams.get("min_avaliacao") ?? "0") || 0,
      max_preco: parseFloat(searchParams.get("max_preco") ?? "999999") || 999999,
      lat: parseFloat(searchParams.get("lat") ?? "0") || undefined,
      lng: parseFloat(searchParams.get("lng") ?? "0") || undefined,
      raio: parseInt(searchParams.get("raio") ?? "10") || 10,
      ordenar: (searchParams.get("ordenar") as BuscaFiltros["ordenar"]) ?? "relevancia",
      page: parseInt(searchParams.get("page") ?? "1") || 1,
      limit: Math.min(parseInt(searchParams.get("limit") ?? "20") || 20, 50),
    };

    const offset = ((filtros.page ?? 1) - 1) * (filtros.limit ?? 20);

    // Busca por proximidade via função PostGIS
    if (filtros.ordenar === "proximidade" && filtros.lat && filtros.lng) {
      const { data, error } = await supabaseAdmin.rpc("buscar_profissionais_proximos", {
        lat: filtros.lat,
        lng: filtros.lng,
        raio_km: filtros.raio,
        categoria_slug: filtros.categoria ?? null,
      });

      if (error) throw error;

      // Registrar busca popular
      await registrarBuscaPopular(filtros);

      return new Response(
        JSON.stringify({
          data: data ?? [],
          meta: { total: data?.length ?? 0, page: filtros.page, limit: filtros.limit },
        }),
        { headers: corsHeaders }
      );
    }

    // Busca padrão via view
    let query = supabaseAdmin
      .from("v_profissionais_completos")
      .select("*", { count: "exact" })
      .gte("media_avaliacao", filtros.min_avaliacao ?? 0)
      .lte("valor_hora", filtros.max_preco ?? 999999);

    if (filtros.categoria) {
      query = query.eq("categoria_slug", filtros.categoria);
    }

    if (filtros.cidade) {
      // Filtro de cidade via JSONB localizacoes
      query = query.contains("localizacoes", [{ cidade: filtros.cidade }]);
    }

    // Ordenação
    switch (filtros.ordenar) {
      case "avaliacao":
        query = query.order("media_avaliacao", { ascending: false });
        break;
      case "preco":
        query = query.order("valor_hora", { ascending: true });
        break;
      default: // relevancia
        query = query
          .order("destaque", { ascending: false })
          .order("media_avaliacao", { ascending: false });
    }

    const { data, error, count } = await query.range(offset, offset + (filtros.limit ?? 20) - 1);

    if (error) throw error;

    // Registrar busca popular assíncrono
    await registrarBuscaPopular(filtros);

    return new Response(
      JSON.stringify({
        data: data ?? [],
        meta: {
          total: count ?? 0,
          page: filtros.page,
          limit: filtros.limit,
          pages: Math.ceil((count ?? 0) / (filtros.limit ?? 20)),
        },
      }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("Erro na busca:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});

async function registrarBuscaPopular(filtros: BuscaFiltros) {
  try {
    const termo = filtros.categoria ?? filtros.cidade ?? "geral";

    // Upsert: incrementa contador se já existe
    const { data: existing } = await supabaseAdmin
      .from("buscas_populares")
      .select("id, contador")
      .eq("termo", termo)
      .maybeSingle();

    if (existing) {
      await supabaseAdmin
        .from("buscas_populares")
        .update({ contador: existing.contador + 1, last_searched: new Date().toISOString() })
        .eq("id", existing.id);
    } else {
      await supabaseAdmin.from("buscas_populares").insert({
        termo,
        cidade: filtros.cidade,
        contador: 1,
      });
    }
  } catch (e) {
    // Não crítico, apenas loga
    console.warn("Erro ao registrar busca popular:", e);
  }
}
