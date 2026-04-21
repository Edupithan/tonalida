-- ============================================================
-- TÔ NA LIDA - Políticas RLS (Row Level Security) v1.0.0
-- ============================================================

-- ==========================================
-- PROFILES
-- ==========================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê próprio perfil"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Profissionais públicos visíveis"
    ON profiles FOR SELECT
    USING (
        tipo = 'profissional' AND 
        EXISTS (SELECT 1 FROM profissionais WHERE profile_id = profiles.id)
    );

CREATE POLICY "Usuário atualiza próprio perfil"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Usuário insere próprio perfil"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- ==========================================
-- ENDEREÇOS
-- ==========================================
ALTER TABLE enderecos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário gerencia próprios endereços"
    ON enderecos FOR ALL
    USING (auth.uid() = profile_id);

CREATE POLICY "Endereços de profissionais visíveis publicamente"
    ON enderecos FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profissionais WHERE profile_id = enderecos.profile_id
        )
    );

-- ==========================================
-- CATEGORIAS (leitura pública)
-- ==========================================
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Categorias visíveis para todos"
    ON categorias FOR SELECT
    USING (ativo = true);

-- ==========================================
-- PROFISSIONAIS
-- ==========================================
ALTER TABLE profissionais ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profissional edita próprio perfil"
    ON profissionais FOR ALL
    USING (auth.uid() = profile_id);

CREATE POLICY "Profissionais visíveis publicamente"
    ON profissionais FOR SELECT
    USING (true);

-- ==========================================
-- ESPECIALIDADES
-- ==========================================
ALTER TABLE profissional_especialidades ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profissional gerencia próprias especialidades"
    ON profissional_especialidades FOR ALL
    USING (auth.uid() = profissional_id);

CREATE POLICY "Especialidades visíveis publicamente"
    ON profissional_especialidades FOR SELECT
    USING (true);

-- ==========================================
-- PORTFÓLIO
-- ==========================================
ALTER TABLE portfolio ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profissional gerencia próprio portfólio"
    ON portfolio FOR ALL
    USING (auth.uid() = profissional_id);

CREATE POLICY "Portfólio visível publicamente"
    ON portfolio FOR SELECT
    USING (true);

-- ==========================================
-- FAVORITOS
-- ==========================================
ALTER TABLE favoritos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Cliente gerencia favoritos"
    ON favoritos FOR ALL
    USING (auth.uid() = cliente_id);

-- ==========================================
-- CONVERSAS
-- ==========================================
ALTER TABLE conversas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participantes veem conversa"
    ON conversas FOR SELECT
    USING (auth.uid() = cliente_id OR auth.uid() = profissional_id);

CREATE POLICY "Cliente cria conversa"
    ON conversas FOR INSERT
    WITH CHECK (auth.uid() = cliente_id);

CREATE POLICY "Participantes atualizam conversa"
    ON conversas FOR UPDATE
    USING (auth.uid() = cliente_id OR auth.uid() = profissional_id);

-- ==========================================
-- MENSAGENS
-- ==========================================
ALTER TABLE mensagens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participantes veem mensagens"
    ON mensagens FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM conversas c 
            WHERE c.id = conversa_id 
            AND (c.cliente_id = auth.uid() OR c.profissional_id = auth.uid())
        )
    );

CREATE POLICY "Remetente insere mensagem"
    ON mensagens FOR INSERT
    WITH CHECK (
        auth.uid() = remetente_id AND
        EXISTS (
            SELECT 1 FROM conversas c 
            WHERE c.id = conversa_id 
            AND (c.cliente_id = auth.uid() OR c.profissional_id = auth.uid())
        )
    );

-- Sem política de UPDATE (mensagens imutáveis)

-- ==========================================
-- AVALIAÇÕES
-- ==========================================
ALTER TABLE avaliacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Cliente cria avaliação"
    ON avaliacoes FOR INSERT
    WITH CHECK (auth.uid() = cliente_id);

CREATE POLICY "Avaliações visíveis publicamente"
    ON avaliacoes FOR SELECT
    USING (visivel = true);

CREATE POLICY "Cliente vê próprias avaliações"
    ON avaliacoes FOR SELECT
    USING (auth.uid() = cliente_id);

CREATE POLICY "Profissional responde avaliação"
    ON avaliacoes FOR UPDATE
    USING (auth.uid() = profissional_id)
    WITH CHECK (
        -- Profissional só pode editar resposta_profissional
        auth.uid() = profissional_id
    );

-- ==========================================
-- NOTIFICAÇÕES
-- ==========================================
ALTER TABLE notificacoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário vê próprias notificações"
    ON notificacoes FOR ALL
    USING (auth.uid() = user_id);

-- ==========================================
-- DEVICE TOKENS
-- ==========================================
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuário gerencia próprios tokens"
    ON device_tokens FOR ALL
    USING (auth.uid() = user_id);

-- ==========================================
-- BUSCAS POPULARES (leitura pública)
-- ==========================================
ALTER TABLE buscas_populares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Buscas populares visíveis para todos"
    ON buscas_populares FOR SELECT
    USING (true);
