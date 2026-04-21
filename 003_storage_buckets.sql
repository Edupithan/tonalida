-- ============================================================
-- TÔ NA LIDA - Storage Buckets Setup v1.0.0
-- ============================================================

-- Bucket: avatars (fotos de perfil) - Público leitura
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Bucket: portfolio (imagens de serviços) - Público leitura
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'portfolio',
    'portfolio',
    true,
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Bucket: documentos (privado - RG, comprovantes)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documentos',
    'documentos',
    false,
    20971520, -- 20MB
    ARRAY['image/jpeg', 'image/png', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- ==========================================
-- Políticas de Storage
-- ==========================================

-- AVATARS: Leitura pública
CREATE POLICY "Avatars visíveis publicamente"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- AVATARS: Usuário faz upload do próprio avatar
CREATE POLICY "Usuário faz upload de avatar"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- AVATARS: Usuário atualiza/deleta próprio avatar
CREATE POLICY "Usuário gerencia próprio avatar"
ON storage.objects FOR UPDATE OR DELETE
USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- PORTFOLIO: Leitura pública
CREATE POLICY "Portfolio visível publicamente"
ON storage.objects FOR SELECT
USING (bucket_id = 'portfolio');

-- PORTFOLIO: Profissional faz upload no próprio diretório
CREATE POLICY "Profissional faz upload no portfólio"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'portfolio' AND
    auth.uid()::text = (storage.foldername(name))[1] AND
    EXISTS (SELECT 1 FROM profissionais WHERE profile_id = auth.uid())
);

-- PORTFOLIO: Profissional gerencia próprias imagens
CREATE POLICY "Profissional gerencia próprio portfólio"
ON storage.objects FOR UPDATE OR DELETE
USING (
    bucket_id = 'portfolio' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- DOCUMENTOS: Apenas o dono visualiza
CREATE POLICY "Usuário vê próprios documentos"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'documentos' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- DOCUMENTOS: Usuário faz upload de documentos
CREATE POLICY "Usuário faz upload de documentos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'documentos' AND
    auth.uid()::text = (storage.foldername(name))[1]
);
