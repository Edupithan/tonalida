// portfolio/upload-imagem.ts
// POST /portfolio/upload-imagem
// Recebe imagem base64, gera thumbnails e salva no Storage

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { supabaseAdmin, getUserFromRequest, corsHeaders } from "../_shared/supabase-client.ts";

interface UploadPayload {
  imagem_base64: string;
  mime_type: "image/jpeg" | "image/png" | "image/webp";
  titulo?: string;
  descricao?: string;
  categoria_id?: string;
  portfolio_id?: string; // Se enviado, atualiza existente
}

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
    // Verificar se é profissional
    const { data: profissional } = await supabaseAdmin
      .from("profissionais")
      .select("profile_id")
      .eq("profile_id", user.id)
      .single();

    if (!profissional) {
      return new Response(
        JSON.stringify({ error: "Apenas profissionais podem fazer upload de portfólio" }),
        { status: 403, headers: corsHeaders }
      );
    }

    const body: UploadPayload = await req.json();
    const { imagem_base64, mime_type, titulo, descricao, categoria_id } = body;

    if (!imagem_base64 || !mime_type) {
      return new Response(
        JSON.stringify({ error: "imagem_base64 e mime_type são obrigatórios" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Decodificar base64
    const imageBytes = Uint8Array.from(atob(imagem_base64), (c) => c.charCodeAt(0));
    const fileSizeMB = imageBytes.length / 1024 / 1024;

    if (fileSizeMB > 10) {
      return new Response(
        JSON.stringify({ error: "Imagem muito grande (máx 10MB)" }),
        { status: 400, headers: corsHeaders }
      );
    }

    const portfolioId = body.portfolio_id ?? crypto.randomUUID();
    const ext = mime_type.split("/")[1].replace("jpeg", "jpg");
    const timestamp = Date.now();

    // Estrutura de pastas: portfolio/{profissional_id}/{portfolio_id}/
    const pathOriginal = `${user.id}/${portfolioId}/original_${timestamp}.${ext}`;
    const pathThumb = `${user.id}/${portfolioId}/thumbnail_${timestamp}.webp`;

    // Upload da imagem original
    const { data: uploadOriginal, error: uploadError } = await supabaseAdmin.storage
      .from("portfolio")
      .upload(pathOriginal, imageBytes, {
        contentType: mime_type,
        upsert: true,
      });

    if (uploadError) {
      console.error("Erro no upload:", uploadError);
      return new Response(
        JSON.stringify({ error: "Erro ao fazer upload da imagem" }),
        { status: 500, headers: corsHeaders }
      );
    }

    // Obter URLs públicas
    const { data: { publicUrl: imagemUrl } } = supabaseAdmin.storage
      .from("portfolio")
      .getPublicUrl(pathOriginal);

    // NOTA: Geração de thumbnail/WebP real exigiria biblioteca de imagem (sharp, imagemagick)
    // Em Deno Edge Functions, podemos usar a API de transformação do Supabase Storage
    // ou um serviço externo. Por ora, usamos a URL com parâmetros de transformação.
    const thumbnailUrl = `${imagemUrl}?width=300&height=300&resize=cover&format=webp`;
    const imageUrl800 = `${imagemUrl}?width=800&height=600&resize=contain&format=webp`;

    // Contar portfólios do profissional para definir ordem
    const { count: totalPortfolio } = await supabaseAdmin
      .from("portfolio")
      .select("id", { count: "exact" })
      .eq("profissional_id", user.id);

    // Inserir registro no banco
    const { data: portfolioRecord, error: dbError } = await supabaseAdmin
      .from("portfolio")
      .insert({
        id: portfolioId,
        profissional_id: user.id,
        titulo: titulo ?? null,
        descricao: descricao ?? null,
        imagem_url: imageUrl800,
        thumbnail_url: thumbnailUrl,
        categoria_id: categoria_id ?? null,
        ordem: (totalPortfolio ?? 0) + 1,
      })
      .select()
      .single();

    if (dbError) {
      // Limpar storage em caso de erro no DB
      await supabaseAdmin.storage.from("portfolio").remove([pathOriginal]);
      return new Response(
        JSON.stringify({ error: "Erro ao salvar registro do portfólio" }),
        { status: 500, headers: corsHeaders }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        portfolio: portfolioRecord,
        urls: {
          original: imagemUrl,
          thumbnail: thumbnailUrl,
          otimizada: imageUrl800,
        },
      }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("Erro no upload:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: corsHeaders }
    );
  }
});
