-- ============================================================
-- TÔ NA LIDA - Seed de Dados Iniciais v1.0.0
-- ============================================================

-- ==========================================
-- CATEGORIAS PRINCIPAIS
-- ==========================================
INSERT INTO categorias (nome, slug, icone, cor, ordem) VALUES
('Construção Civil', 'construcao-civil', 'construction', '#FF6B35', 1),
('Marcenaria & Móveis', 'marcenaria', 'carpenter', '#8B4513', 2),
('Automotivo', 'automotivo', 'directions_car', '#1565C0', 3),
('Beleza & Estética', 'beleza', 'spa', '#C2185B', 4),
('Tecnologia & Design', 'tecnologia', 'computer', '#00796B', 5),
('Eventos & Alimentação', 'eventos', 'celebration', '#6A1B9A', 6),
('Domésticos & Limpeza', 'domesticos', 'home', '#558B2F', 7),
('Saúde & Bem-estar', 'saude', 'favorite', '#D32F2F', 8),
('Outros Serviços', 'outros', 'handyman', '#455A64', 9);

-- ==========================================
-- SUBCATEGORIAS - Construção Civil
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Pintor', 'pintor', 'format_paint', id, 1 FROM categorias WHERE slug = 'construcao-civil';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Pedreiro', 'pedreiro', 'construction', id, 2 FROM categorias WHERE slug = 'construcao-civil';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Azulejista', 'azulejista', 'grid_on', id, 3 FROM categorias WHERE slug = 'construcao-civil';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Gesseiro', 'gesseiro', 'texture', id, 4 FROM categorias WHERE slug = 'construcao-civil';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Encanador', 'encanador', 'plumbing', id, 5 FROM categorias WHERE slug = 'construcao-civil';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Eletricista', 'eletricista', 'electrical_services', id, 6 FROM categorias WHERE slug = 'construcao-civil';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Serralheiro', 'serralheiro', 'settings', id, 7 FROM categorias WHERE slug = 'construcao-civil';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Vidraceiro', 'vidraceiro', 'window', id, 8 FROM categorias WHERE slug = 'construcao-civil';

-- ==========================================
-- SUBCATEGORIAS - Marcenaria
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Marceneiro', 'marceneiro', 'carpenter', id, 1 FROM categorias WHERE slug = 'marcenaria';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Montador de Móveis', 'montador-moveis', 'chair', id, 2 FROM categorias WHERE slug = 'marcenaria';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Restaurador de Móveis', 'restaurador-moveis', 'auto_fix_high', id, 3 FROM categorias WHERE slug = 'marcenaria';

-- ==========================================
-- SUBCATEGORIAS - Automotivo
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Mecânico', 'mecanico', 'build', id, 1 FROM categorias WHERE slug = 'automotivo';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Funileiro', 'funileiro', 'car_repair', id, 2 FROM categorias WHERE slug = 'automotivo';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Pintor Automotivo', 'pintor-automotivo', 'format_paint', id, 3 FROM categorias WHERE slug = 'automotivo';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Guincho', 'guincho', 'local_shipping', id, 4 FROM categorias WHERE slug = 'automotivo';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Lava-jato Detalhado', 'lava-jato', 'local_car_wash', id, 5 FROM categorias WHERE slug = 'automotivo';

-- ==========================================
-- SUBCATEGORIAS - Beleza
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Cabeleireiro', 'cabeleireiro', 'content_cut', id, 1 FROM categorias WHERE slug = 'beleza';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Manicure/Pedicure', 'manicure', 'spa', id, 2 FROM categorias WHERE slug = 'beleza';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Maquiador', 'maquiador', 'face', id, 3 FROM categorias WHERE slug = 'beleza';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Barbeiro', 'barbeiro', 'content_cut', id, 4 FROM categorias WHERE slug = 'beleza';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Esteticista', 'esteticista', 'self_improvement', id, 5 FROM categorias WHERE slug = 'beleza';

-- ==========================================
-- SUBCATEGORIAS - Eventos
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Confeiteiro', 'confeiteiro', 'cake', id, 1 FROM categorias WHERE slug = 'eventos';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Buffet', 'buffet', 'restaurant', id, 2 FROM categorias WHERE slug = 'eventos';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Bartender', 'bartender', 'local_bar', id, 3 FROM categorias WHERE slug = 'eventos';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'DJ', 'dj', 'music_note', id, 4 FROM categorias WHERE slug = 'eventos';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Fotógrafo', 'fotografo', 'photo_camera', id, 5 FROM categorias WHERE slug = 'eventos';

-- ==========================================
-- SUBCATEGORIAS - Domésticos
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Diarista', 'diarista', 'cleaning_services', id, 1 FROM categorias WHERE slug = 'domesticos';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Jardineiro', 'jardineiro', 'yard', id, 2 FROM categorias WHERE slug = 'domesticos';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Piscineiro', 'piscineiro', 'pool', id, 3 FROM categorias WHERE slug = 'domesticos';

-- ==========================================
-- SUBCATEGORIAS - Saúde
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Cuidador de Idosos', 'cuidador-idosos', 'elderly', id, 1 FROM categorias WHERE slug = 'saude';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Babá', 'baba', 'child_care', id, 2 FROM categorias WHERE slug = 'saude';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Personal Trainer', 'personal-trainer', 'fitness_center', id, 3 FROM categorias WHERE slug = 'saude';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Nutricionista', 'nutricionista', 'restaurant_menu', id, 4 FROM categorias WHERE slug = 'saude';

-- ==========================================
-- SUBCATEGORIAS - Outros
-- ==========================================
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Chaveiro', 'chaveiro', 'key', id, 1 FROM categorias WHERE slug = 'outros';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Desentupidor', 'desentupidor', 'plumbing', id, 2 FROM categorias WHERE slug = 'outros';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Dedetizador', 'dedetizador', 'pest_control', id, 3 FROM categorias WHERE slug = 'outros';
INSERT INTO categorias (nome, slug, icone, parent_id, ordem) 
SELECT 'Marido de Aluguel', 'marido-aluguel', 'handyman', id, 4 FROM categorias WHERE slug = 'outros';
