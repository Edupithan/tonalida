-- ============================================================
-- TÔ NA LIDA - Schema Inicial v1.0.0
-- Plataforma de conexão entre profissionais autônomos e clientes
-- ============================================================

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ==========================================
-- 1. PERFIS (Polimórfico: Profissional ou Cliente)
-- ==========================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tipo VARCHAR(20) CHECK (tipo IN ('profissional', 'cliente')) NOT NULL,
    nome_completo VARCHAR(100) NOT NULL,
    telefone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    avatar_url TEXT,
    cpf_cnpj VARCHAR(18) UNIQUE, -- Opcional, para faturamento
    data_nascimento DATE,
    genero VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'ativo' CHECK (status IN ('ativo', 'inativo', 'suspenso', 'verificando'))
);

-- Trigger: updated_at automático
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ==========================================
-- 2. ENDEREÇOS (Reutilizável)
-- ==========================================
CREATE TABLE enderecos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    tipo VARCHAR(20) CHECK (tipo IN ('residencial', 'comercial', 'atendimento')),
    cep VARCHAR(9) NOT NULL,
    logradouro VARCHAR(200) NOT NULL,
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100) NOT NULL,
    cidade VARCHAR(100) NOT NULL,
    estado VARCHAR(2) NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    geom GEOMETRY(Point, 4326), -- PostGIS
    raio_atuacao_km INT DEFAULT 10, -- Para profissionais
    is_principal BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_enderecos_geom ON enderecos USING GIST(geom);
CREATE INDEX idx_enderecos_profile ON enderecos(profile_id);

-- Trigger: preencher geom automaticamente a partir de lat/lng
CREATE OR REPLACE FUNCTION sync_geom_from_latlon()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_geom
BEFORE INSERT OR UPDATE ON enderecos
FOR EACH ROW EXECUTE FUNCTION sync_geom_from_latlon();

-- ==========================================
-- 3. CATEGORIAS (Hierárquica)
-- ==========================================
CREATE TABLE categorias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(100) NOT NULL UNIQUE,
    slug VARCHAR(100) UNIQUE NOT NULL,
    icone VARCHAR(50),
    cor VARCHAR(7), -- Hex color
    parent_id UUID REFERENCES categorias(id),
    ordem INT DEFAULT 0,
    ativo BOOLEAN DEFAULT true
);

-- ==========================================
-- 4. PROFISSIONAIS (Extensão de Profile)
-- ==========================================
CREATE TABLE profissionais (
    profile_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    bio TEXT,
    experiencia_anos INT,
    categoria_principal_id UUID REFERENCES categorias(id),
    valor_hora DECIMAL(10,2),
    valor_visita DECIMAL(10,2),
    aceita_remoto BOOLEAN DEFAULT false,
    aceita_presencial BOOLEAN DEFAULT true,
    dias_atendimento INT[] DEFAULT '{1,2,3,4,5}', -- 0=Dom, 6=Sab
    horario_inicio TIME DEFAULT '08:00',
    horario_fim TIME DEFAULT '18:00',
    verificado BOOLEAN DEFAULT false,
    destaque BOOLEAN DEFAULT false,
    media_avaliacao DECIMAL(2,1) DEFAULT 0 CHECK (media_avaliacao >= 0 AND media_avaliacao <= 5),
    total_avaliacoes INT DEFAULT 0,
    total_servicos INT DEFAULT 0,
    documento_verificado BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 5. ESPECIALIDADES (N:N Profissional-Categoria)
-- ==========================================
CREATE TABLE profissional_especialidades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profissional_id UUID REFERENCES profissionais(profile_id) ON DELETE CASCADE,
    categoria_id UUID REFERENCES categorias(id) ON DELETE CASCADE,
    descricao TEXT,
    UNIQUE(profissional_id, categoria_id)
);

-- ==========================================
-- 6. PORTFÓLIO (Imagens dos serviços)
-- ==========================================
CREATE TABLE portfolio (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profissional_id UUID REFERENCES profissionais(profile_id) ON DELETE CASCADE,
    titulo VARCHAR(200),
    descricao TEXT,
    imagem_url TEXT NOT NULL,
    thumbnail_url TEXT,
    categoria_id UUID REFERENCES categorias(id),
    ordem INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- 7. FAVORITOS (Cliente salva Profissional)
-- ==========================================
CREATE TABLE favoritos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    profissional_id UUID REFERENCES profissionais(profile_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cliente_id, profissional_id)
);

-- ==========================================
-- 8. CHATS & MENSAGENS
-- ==========================================
CREATE TABLE conversas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    profissional_id UUID REFERENCES profissionais(profile_id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'ativo' CHECK (status IN ('ativo', 'arquivado', 'bloqueado')),
    ultima_mensagem TEXT,
    ultima_mensagem_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cliente_id, profissional_id)
);

CREATE TABLE mensagens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversa_id UUID REFERENCES conversas(id) ON DELETE CASCADE,
    remetente_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    tipo VARCHAR(20) DEFAULT 'texto' CHECK (tipo IN ('texto', 'imagem', 'orcamento', 'localizacao', 'sistema')),
    conteudo TEXT NOT NULL,
    metadata JSONB, -- {valor: 100, servico: "Pintura", prazo: "3 dias"}
    lida BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
    -- NOTA: Sem UPDATE permitido (mensagens imutáveis conforme spec)
);

CREATE INDEX idx_mensagens_conversa ON mensagens(conversa_id, created_at DESC);

-- ==========================================
-- 9. AVALIAÇÕES
-- ==========================================
CREATE TABLE avaliacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    profissional_id UUID REFERENCES profissionais(profile_id) ON DELETE CASCADE,
    conversa_id UUID REFERENCES conversas(id),
    nota INT CHECK (nota >= 1 AND nota <= 5),
    comentario TEXT,
    tags TEXT[], -- ['pontual', 'profissional', 'limpo', 'caro', 'demorado']
    visivel BOOLEAN DEFAULT true,
    resposta_profissional TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cliente_id, conversa_id) -- Um cliente avalia uma vez por conversa/serviço
);

-- ==========================================
-- 10. NOTIFICAÇÕES
-- ==========================================
CREATE TABLE notificacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    tipo VARCHAR(50) NOT NULL, -- 'nova_mensagem', 'novo_orcamento', 'avaliacao', 'sistema'
    titulo VARCHAR(200) NOT NULL,
    corpo TEXT NOT NULL,
    dados JSONB, -- {conversa_id: "uuid", profissional_id: "uuid"}
    lida BOOLEAN DEFAULT false,
    enviado_push BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notificacoes_user ON notificacoes(user_id, lida, created_at DESC);

-- ==========================================
-- 11. DEVICE TOKENS (FCM)
-- ==========================================
CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL,
    plataforma VARCHAR(10) CHECK (plataforma IN ('android', 'ios')),
    app_version VARCHAR(20),
    ativo BOOLEAN DEFAULT true,
    last_used TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);

-- ==========================================
-- 12. BUSCAS CACHE (Performance)
-- ==========================================
CREATE TABLE buscas_populares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    termo VARCHAR(200) NOT NULL,
    categoria_id UUID REFERENCES categorias(id),
    cidade VARCHAR(100),
    contador INT DEFAULT 1,
    last_searched TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- VIEWS
-- ==========================================

-- View: Profissionais com informações completas para busca
CREATE VIEW v_profissionais_completos AS
SELECT 
    p.id,
    p.nome_completo,
    p.avatar_url,
    p.telefone,
    prof.bio,
    prof.experiencia_anos,
    prof.valor_hora,
    prof.valor_visita,
    prof.media_avaliacao,
    prof.total_avaliacoes,
    prof.verificado,
    prof.destaque,
    prof.dias_atendimento,
    prof.horario_inicio,
    prof.horario_fim,
    prof.aceita_remoto,
    prof.aceita_presencial,
    c.nome as categoria_principal,
    c.slug as categoria_slug,
    c.icone as categoria_icone,
    json_agg(DISTINCT jsonb_build_object(
        'id', cat.id,
        'nome', cat.nome,
        'descricao', pe.descricao
    )) FILTER (WHERE cat.id IS NOT NULL) as especialidades,
    json_agg(DISTINCT jsonb_build_object(
        'id', port.id,
        'titulo', port.titulo,
        'imagem', port.imagem_url,
        'thumbnail', port.thumbnail_url
    )) FILTER (WHERE port.id IS NOT NULL) as portfolio_preview,
    json_agg(DISTINCT jsonb_build_object(
        'cidade', e.cidade,
        'estado', e.estado,
        'bairro', e.bairro,
        'raio_km', e.raio_atuacao_km
    )) FILTER (WHERE e.id IS NOT NULL) as localizacoes
FROM profiles p
JOIN profissionais prof ON p.id = prof.profile_id
LEFT JOIN categorias c ON prof.categoria_principal_id = c.id
LEFT JOIN profissional_especialidades pe ON prof.profile_id = pe.profissional_id
LEFT JOIN categorias cat ON pe.categoria_id = cat.id
LEFT JOIN portfolio port ON prof.profile_id = port.profissional_id
LEFT JOIN enderecos e ON p.id = e.profile_id AND e.is_principal = true
WHERE p.status = 'ativo'
GROUP BY p.id, prof.profile_id, c.id;

-- ==========================================
-- FUNÇÕES & TRIGGERS
-- ==========================================

-- Função: Busca por proximidade geográfica
CREATE OR REPLACE FUNCTION buscar_profissionais_proximos(
    lat DECIMAL,
    lng DECIMAL,
    raio_km INT DEFAULT 10,
    categoria_slug VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    nome_completo VARCHAR,
    distancia_km DECIMAL,
    media_avaliacao DECIMAL,
    categoria_nome VARCHAR,
    valor_hora DECIMAL,
    avatar_url TEXT,
    verificado BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.nome_completo,
        ROUND(
            (ST_Distance(e.geom::geography, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) / 1000)::DECIMAL,
            1
        ) as distancia_km,
        prof.media_avaliacao,
        c.nome as categoria_nome,
        prof.valor_hora,
        p.avatar_url,
        prof.verificado
    FROM profiles p
    JOIN profissionais prof ON p.id = prof.profile_id
    JOIN enderecos e ON p.id = e.profile_id AND e.is_principal = true
    LEFT JOIN categorias c ON prof.categoria_principal_id = c.id
    WHERE ST_DWithin(
        e.geom::geography,
        ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
        raio_km * 1000
    )
    AND (categoria_slug IS NULL OR c.slug = categoria_slug)
    AND p.status = 'ativo'
    ORDER BY distancia_km;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Atualizar média de avaliações automaticamente
CREATE OR REPLACE FUNCTION atualizar_media_avaliacoes()
RETURNS TRIGGER AS $$
DECLARE
    prof_id UUID;
BEGIN
    -- Suporta INSERT, UPDATE e DELETE
    IF TG_OP = 'DELETE' THEN
        prof_id := OLD.profissional_id;
    ELSE
        prof_id := NEW.profissional_id;
    END IF;

    UPDATE profissionais
    SET 
        media_avaliacao = COALESCE((
            SELECT ROUND(AVG(nota)::DECIMAL, 1)
            FROM avaliacoes 
            WHERE profissional_id = prof_id AND visivel = true
        ), 0),
        total_avaliacoes = (
            SELECT COUNT(*) 
            FROM avaliacoes 
            WHERE profissional_id = prof_id AND visivel = true
        )
    WHERE profile_id = prof_id;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_atualizar_media
AFTER INSERT OR UPDATE OR DELETE ON avaliacoes
FOR EACH ROW EXECUTE FUNCTION atualizar_media_avaliacoes();

-- Trigger: Garantir que mensagens não possam ser atualizadas (imutáveis)
CREATE OR REPLACE FUNCTION bloquear_update_mensagens()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Mensagens são imutáveis e não podem ser alteradas.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mensagens_imutaveis
BEFORE UPDATE ON mensagens
FOR EACH ROW EXECUTE FUNCTION bloquear_update_mensagens();

-- ==========================================
-- REALTIME
-- ==========================================
ALTER TABLE mensagens REPLICA IDENTITY FULL;
ALTER TABLE notificacoes REPLICA IDENTITY FULL;
ALTER TABLE conversas REPLICA IDENTITY FULL;
