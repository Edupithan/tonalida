// _shared/types.ts
// Tipagens TypeScript compartilhadas entre Edge Functions

export type TipoPerfil = "profissional" | "cliente";
export type StatusPerfil = "ativo" | "inativo" | "suspenso" | "verificando";
export type TipoMensagem = "texto" | "imagem" | "orcamento" | "localizacao" | "sistema";
export type StatusConversa = "ativo" | "arquivado" | "bloqueado";
export type PlataformaDevice = "android" | "ios";
export type TipoNotificacao = "nova_mensagem" | "novo_orcamento" | "avaliacao" | "sistema";

export interface Profile {
  id: string;
  tipo: TipoPerfil;
  nome_completo: string;
  telefone: string;
  email: string;
  avatar_url?: string;
  cpf_cnpj?: string;
  data_nascimento?: string;
  genero?: string;
  created_at: string;
  updated_at: string;
  status: StatusPerfil;
}

export interface Profissional {
  profile_id: string;
  bio?: string;
  experiencia_anos?: number;
  categoria_principal_id?: string;
  valor_hora?: number;
  valor_visita?: number;
  aceita_remoto: boolean;
  aceita_presencial: boolean;
  dias_atendimento: number[];
  horario_inicio: string;
  horario_fim: string;
  verificado: boolean;
  destaque: boolean;
  media_avaliacao: number;
  total_avaliacoes: number;
  total_servicos: number;
  documento_verificado: boolean;
}

export interface Categoria {
  id: string;
  nome: string;
  slug: string;
  icone?: string;
  cor?: string;
  parent_id?: string;
  ordem: number;
  ativo: boolean;
}

export interface MensagemPayload {
  conversa_id: string;
  conteudo: string;
  tipo?: TipoMensagem;
  metadata?: Record<string, unknown>;
}

export interface OrcamentoMetadata {
  valor: number;
  servico: string;
  prazo: string;
  descricao?: string;
}

export interface PushNotificationPayload {
  tokens: string[];
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

export interface BuscaFiltros {
  categoria?: string;
  cidade?: string;
  min_avaliacao?: number;
  max_preco?: number;
  lat?: number;
  lng?: number;
  raio?: number;
  ordenar?: "relevancia" | "avaliacao" | "preco" | "proximidade";
  page?: number;
  limit?: number;
}

export interface ApiResponse<T = unknown> {
  data?: T;
  error?: string;
  message?: string;
}
