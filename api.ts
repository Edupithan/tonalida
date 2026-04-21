// services/api.ts
// Camada de serviço que abstrai chamadas ao Supabase e Edge Functions

import { createClient, SupabaseClient, RealtimeChannel } from "@supabase/supabase-js";

// Configuração via variáveis de ambiente (substitua em produção)
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL ?? "";
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY ?? "";

export const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ==========================================
// AUTH
// ==========================================
export const authService = {
  async signUp(email: string, password: string, tipo: "profissional" | "cliente", nome_completo: string, telefone: string) {
    return supabase.auth.signUp({
      email,
      password,
      options: {
        data: { tipo, nome_completo, telefone },
      },
    });
  },

  async signIn(email: string, password: string) {
    return supabase.auth.signInWithPassword({ email, password });
  },

  async signOut() {
    return supabase.auth.signOut();
  },

  async getSession() {
    return supabase.auth.getSession();
  },

  async getUser() {
    return supabase.auth.getUser();
  },

  onAuthStateChange(callback: Parameters<typeof supabase.auth.onAuthStateChange>[0]) {
    return supabase.auth.onAuthStateChange(callback);
  },
};

// ==========================================
// PERFIS
// ==========================================
export const profileService = {
  async getProfile(id: string) {
    return supabase.from("profiles").select("*").eq("id", id).single();
  },

  async updateProfile(id: string, data: Record<string, unknown>) {
    return supabase.from("profiles").update(data).eq("id", id).select().single();
  },

  async uploadAvatar(userId: string, file: File) {
    const ext = file.name.split(".").pop();
    const path = `${userId}/avatar.${ext}`;
    const { error } = await supabase.storage.from("avatars").upload(path, file, { upsert: true });
    if (error) throw error;
    const { data } = supabase.storage.from("avatars").getPublicUrl(path);
    return data.publicUrl;
  },
};

// ==========================================
// PROFISSIONAIS
// ==========================================
export const profissionalService = {
  async getProfissional(profileId: string) {
    return supabase
      .from("v_profissionais_completos")
      .select("*")
      .eq("id", profileId)
      .single();
  },

  async updateProfissional(profileId: string, data: Record<string, unknown>) {
    return supabase.from("profissionais").update(data).eq("profile_id", profileId).select().single();
  },

  async createProfissional(data: Record<string, unknown>) {
    return supabase.from("profissionais").insert(data).select().single();
  },

  async buscarProfissionais(filtros: {
    categoria?: string;
    cidade?: string;
    min_avaliacao?: number;
    max_preco?: number;
    lat?: number;
    lng?: number;
    raio?: number;
    ordenar?: string;
    page?: number;
  }) {
    const params = new URLSearchParams();
    Object.entries(filtros).forEach(([k, v]) => {
      if (v !== undefined && v !== null) params.set(k, String(v));
    });

    const response = await fetch(
      `${SUPABASE_URL}/functions/v1/busca/profissionais?${params}`,
      {
        headers: {
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );
    return response.json();
  },

  async addEspecialidade(profissionalId: string, categoriaId: string, descricao?: string) {
    return supabase.from("profissional_especialidades").insert({
      profissional_id: profissionalId,
      categoria_id: categoriaId,
      descricao,
    });
  },

  async removeEspecialidade(id: string) {
    return supabase.from("profissional_especialidades").delete().eq("id", id);
  },
};

// ==========================================
// CATEGORIAS
// ==========================================
export const categoriaService = {
  async listarCategorias(somenteRaiz = false) {
    let query = supabase.from("categorias").select("*").eq("ativo", true).order("ordem");
    if (somenteRaiz) query = query.is("parent_id", null);
    return query;
  },

  async getSubcategorias(parentId: string) {
    return supabase.from("categorias").select("*").eq("parent_id", parentId).eq("ativo", true).order("ordem");
  },
};

// ==========================================
// CONVERSAS & MENSAGENS
// ==========================================
export const chatService = {
  async listarConversas(userId: string) {
    return supabase
      .from("conversas")
      .select(`
        *,
        cliente:profiles!conversas_cliente_id_fkey(id, nome_completo, avatar_url),
        profissional:profissionais!conversas_profissional_id_fkey(
          profile_id,
          profiles(id, nome_completo, avatar_url)
        )
      `)
      .or(`cliente_id.eq.${userId},profissional_id.eq.${userId}`)
      .order("ultima_mensagem_at", { ascending: false });
  },

  async getOuCriarConversa(clienteId: string, profissionalId: string) {
    // Tenta buscar conversa existente
    const { data: existing } = await supabase
      .from("conversas")
      .select("*")
      .eq("cliente_id", clienteId)
      .eq("profissional_id", profissionalId)
      .single();

    if (existing) return { data: existing, error: null };

    // Cria nova conversa
    return supabase
      .from("conversas")
      .insert({ cliente_id: clienteId, profissional_id: profissionalId })
      .select()
      .single();
  },

  async listarMensagens(conversaId: string, page = 1, limit = 50) {
    const offset = (page - 1) * limit;
    return supabase
      .from("mensagens")
      .select("*")
      .eq("conversa_id", conversaId)
      .order("created_at", { ascending: true })
      .range(offset, offset + limit - 1);
  },

  async enviarMensagem(token: string, payload: {
    conversa_id: string;
    conteudo: string;
    tipo?: string;
    metadata?: Record<string, unknown>;
  }) {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/chat/enviar-mensagem`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    return response.json();
  },

  async marcarLida(token: string, conversaId: string) {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/chat/marcar-lida`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ conversa_id: conversaId }),
    });
    return response.json();
  },

  subscribeToConversa(conversaId: string, onMessage: (payload: unknown) => void): RealtimeChannel {
    return supabase
      .channel(`conversa:${conversaId}`)
      .on("postgres_changes", {
        event: "INSERT",
        schema: "public",
        table: "mensagens",
        filter: `conversa_id=eq.${conversaId}`,
      }, onMessage)
      .subscribe();
  },

  unsubscribe(channel: RealtimeChannel) {
    supabase.removeChannel(channel);
  },
};

// ==========================================
// FAVORITOS
// ==========================================
export const favoritosService = {
  async listarFavoritos(clienteId: string) {
    return supabase
      .from("favoritos")
      .select("*, profissional:profissionais(profile_id, media_avaliacao, valor_hora, profiles(nome_completo, avatar_url))")
      .eq("cliente_id", clienteId)
      .order("created_at", { ascending: false });
  },

  async adicionar(clienteId: string, profissionalId: string) {
    return supabase.from("favoritos").insert({ cliente_id: clienteId, profissional_id: profissionalId });
  },

  async remover(clienteId: string, profissionalId: string) {
    return supabase
      .from("favoritos")
      .delete()
      .eq("cliente_id", clienteId)
      .eq("profissional_id", profissionalId);
  },

  async verificar(clienteId: string, profissionalId: string) {
    const { data } = await supabase
      .from("favoritos")
      .select("id")
      .eq("cliente_id", clienteId)
      .eq("profissional_id", profissionalId)
      .single();
    return !!data;
  },
};

// ==========================================
// AVALIAÇÕES
// ==========================================
export const avaliacaoService = {
  async listarAvaliacoes(profissionalId: string) {
    return supabase
      .from("avaliacoes")
      .select("*, cliente:profiles!avaliacoes_cliente_id_fkey(nome_completo, avatar_url)")
      .eq("profissional_id", profissionalId)
      .eq("visivel", true)
      .order("created_at", { ascending: false });
  },

  async criar(data: {
    cliente_id: string;
    profissional_id: string;
    conversa_id: string;
    nota: number;
    comentario?: string;
    tags?: string[];
  }) {
    return supabase.from("avaliacoes").insert(data).select().single();
  },

  async responderAvaliacao(avaliacaoId: string, resposta: string) {
    return supabase
      .from("avaliacoes")
      .update({ resposta_profissional: resposta })
      .eq("id", avaliacaoId)
      .select()
      .single();
  },
};

// ==========================================
// NOTIFICAÇÕES
// ==========================================
export const notificacaoService = {
  async listar(userId: string) {
    return supabase
      .from("notificacoes")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50);
  },

  async marcarLida(id: string) {
    return supabase.from("notificacoes").update({ lida: true }).eq("id", id);
  },

  async marcarTodasLidas(userId: string) {
    return supabase.from("notificacoes").update({ lida: true }).eq("user_id", userId).eq("lida", false);
  },

  subscribeToNotificacoes(userId: string, onNotificacao: (payload: unknown) => void): RealtimeChannel {
    return supabase
      .channel(`notificacoes:${userId}`)
      .on("postgres_changes", {
        event: "INSERT",
        schema: "public",
        table: "notificacoes",
        filter: `user_id=eq.${userId}`,
      }, onNotificacao)
      .subscribe();
  },
};

// ==========================================
// DEVICE TOKENS
// ==========================================
export const deviceTokenService = {
  async registrar(userId: string, token: string, plataforma: "android" | "ios", appVersion?: string) {
    return supabase.from("device_tokens").upsert(
      { user_id: userId, token, plataforma, app_version: appVersion, ativo: true, last_used: new Date().toISOString() },
      { onConflict: "user_id,token" }
    );
  },

  async desativar(userId: string, token: string) {
    return supabase.from("device_tokens").update({ ativo: false }).eq("user_id", userId).eq("token", token);
  },
};
