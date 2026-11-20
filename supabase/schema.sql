-- =============================================================================
--  Catálogo — modelagem do banco (Supabase / PostgreSQL)
--  Rodar UMA vez no SQL Editor do Supabase (projeto novo).
--
--  Princípios:
--   - multi-loja desde a base (stores + store_id em tudo)
--   - estoque por SKU (variante × cor), não número solto
--   - integridade forçada pelo banco (FKs compostas), não pela aplicação
--   - RLS: público não lê tabela direto; só a função get_catalog() expõe
--     dados públicos. Lojista autenticado só mexe na própria loja.
-- =============================================================================

-- ---------- tipos ----------
create type condicao as enum ('novo', 'seminovo');
create type store_role as enum ('owner', 'staff');

-- ---------- utilitários ----------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

-- =============================================================================
--  TABELAS
-- =============================================================================

-- ---------- loja (perfil + configuração de pagamento) ----------
create table stores (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique,              -- usado na rota/multi-loja
  nome               text not null,
  sigla              text,
  bairro             text,
  whatsapp           text not null,                     -- só dígitos (DDI+DDD+num)
  endereco           text,
  horario            text,
  cor_destaque       text not null default '#8B5CF6' check (cor_destaque ~ '^#[0-9A-Fa-f]{3,8}$'),
  garantia_novo      text,
  garantia_seminovo  text,
  obs_novo           text,
  obs_seminovo       text,
  -- pagamento (escalares)
  repassa_juros      boolean not null default true,
  mostrar_taxa       boolean not null default true,
  parcelas_sem_juros int not null default 1 check (parcelas_sem_juros >= 0),
  max_parcelas       int not null default 12 check (max_parcelas between 1 and 24),
  ativa              boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- ---------- vínculo usuário ↔ loja (quem pode administrar) ----------
create table store_members (
  store_id   uuid not null references stores(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       store_role not null default 'owner',
  created_at timestamptz not null default now(),
  primary key (store_id, user_id)
);

-- ---------- taxas da maquininha por nº de parcelas ----------
create table payment_fees (
  store_id uuid not null references stores(id) on delete cascade,
  parcelas int not null check (parcelas >= 1),
  taxa_pct numeric(5,2) not null check (taxa_pct >= 0),
  primary key (store_id, parcelas)
);

-- ---------- produtos ----------
create table products (
  id         uuid primary key default gen_random_uuid(),
  store_id   uuid not null references stores(id) on delete cascade,
  slug       text not null,                              -- ex.: "iphone-15" (id na URL do catálogo)
  marca      text not null,
  modelo     text not null,
  cam        text not null default 'default',            -- estilo do desenho (apple-v, samsung, ...)
  tela       text,
  chip       text,
  camera     text,
  bateria    text,                                       -- texto da ficha (ex.: "Até 20h de vídeo")
  ordem      int not null default 0,
  publicado  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, slug),
  unique (id, store_id)                                  -- alvo de FK composta
);

-- ---------- cores (paleta do produto + hex) ----------
create table product_colors (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null,
  store_id   uuid not null,
  nome       text not null,
  hex        text not null default '#3A3A3C' check (hex ~ '^#[0-9A-Fa-f]{3,8}$'),
  ordem      int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (product_id, store_id) references products(id, store_id) on delete cascade,
  unique (product_id, nome),
  unique (id, product_id)                                -- alvo de FK composta
);

-- ---------- fotos (por cor, ordenadas; path no Storage) ----------
create table product_photos (
  id         uuid primary key default gen_random_uuid(),
  color_id   uuid not null,
  product_id uuid not null,
  store_id   uuid not null,
  path       text not null,                              -- objeto no bucket "fotos" (<store_id>/...)
  ordem      int not null default 0,
  created_at timestamptz not null default now(),
  foreign key (color_id, product_id) references product_colors(id, product_id) on delete cascade,
  foreign key (product_id, store_id) references products(id, store_id) on delete cascade
);

-- ---------- variantes (GB + condição + preço) ----------
create table variants (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null,
  store_id   uuid not null,
  gb         int not null check (gb > 0),
  condicao   condicao not null,
  preco_pix  numeric(10,2) not null check (preco_pix >= 0),
  bateria    int check (bateria between 0 and 100),      -- seminovo
  estado     text,                                       -- seminovo (ex.: "Excelente")
  ordem      int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (product_id, store_id) references products(id, store_id) on delete cascade,
  unique (product_id, gb, condicao),
  unique (id, product_id),                               -- alvo de FK composta
  -- seminovo exige bateria + estado; novo não tem
  check (condicao <> 'seminovo' or (bateria is not null and estado is not null))
);

-- ---------- estoque por SKU (variante × cor) ----------
create table variant_colors (
  variant_id uuid not null,
  color_id   uuid not null,
  product_id uuid not null,
  store_id   uuid not null,
  estoque    int not null default 0 check (estoque >= 0),
  updated_at timestamptz not null default now(),
  primary key (variant_id, color_id),
  -- variante e cor têm de ser do MESMO produto (integridade forçada):
  foreign key (variant_id, product_id) references variants(id, product_id) on delete cascade,
  foreign key (color_id, product_id)   references product_colors(id, product_id) on delete cascade,
  foreign key (product_id, store_id)   references products(id, store_id) on delete cascade
);

-- ---------- índices (RLS e joins) ----------
create index on store_members (user_id);
create index on payment_fees (store_id);
create index on products (store_id);
create index on product_colors (product_id);
create index on product_colors (store_id);
create index on product_photos (color_id);
create index on product_photos (store_id);
create index on variants (product_id);
create index on variants (store_id);
create index on variant_colors (color_id);
create index on variant_colors (store_id);

-- ---------- triggers updated_at ----------
create trigger t_upd before update on stores         for each row execute function set_updated_at();
create trigger t_upd before update on products       for each row execute function set_updated_at();
create trigger t_upd before update on product_colors for each row execute function set_updated_at();
create trigger t_upd before update on variants       for each row execute function set_updated_at();
create trigger t_upd before update on variant_colors for each row execute function set_updated_at();

-- =============================================================================
--  Funções de autorização (depois das tabelas que elas consultam).
--  SECURITY DEFINER para não recursar no RLS de store_members.
-- =============================================================================
create or replace function is_store_member(p_store uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from store_members
                 where store_id = p_store and user_id = auth.uid());
$$;

create or replace function is_store_owner(p_store uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from store_members
                 where store_id = p_store and user_id = auth.uid() and role = 'owner');
$$;

-- =============================================================================
--  RLS — por padrão nega tudo; liberamos só o necessário
-- =============================================================================
alter table stores          enable row level security;
alter table store_members   enable row level security;
alter table payment_fees    enable row level security;
alter table products        enable row level security;
alter table product_colors  enable row level security;
alter table product_photos  enable row level security;
alter table variants        enable row level security;
alter table variant_colors  enable row level security;

-- membros: cada um vê os próprios vínculos; dono gerencia a equipe da loja
create policy m_select on store_members for select to authenticated
  using (user_id = auth.uid());
create policy m_manage on store_members for all to authenticated
  using (is_store_owner(store_id)) with check (is_store_owner(store_id));

-- demais tabelas: membros da loja têm CRUD completo nos dados da própria loja
create policy s_rw  on stores         for all to authenticated using (is_store_member(id))       with check (is_store_member(id));
create policy pf_rw on payment_fees   for all to authenticated using (is_store_member(store_id)) with check (is_store_member(store_id));
create policy p_rw  on products       for all to authenticated using (is_store_member(store_id)) with check (is_store_member(store_id));
create policy pc_rw on product_colors for all to authenticated using (is_store_member(store_id)) with check (is_store_member(store_id));
create policy pp_rw on product_photos for all to authenticated using (is_store_member(store_id)) with check (is_store_member(store_id));
create policy v_rw  on variants       for all to authenticated using (is_store_member(store_id)) with check (is_store_member(store_id));
create policy vc_rw on variant_colors for all to authenticated using (is_store_member(store_id)) with check (is_store_member(store_id));

-- grants (RLS ainda filtra as linhas; o grant só dá o privilégio ao papel)
grant select, insert, update, delete on all tables in schema public to authenticated;

-- =============================================================================
--  LEITURA PÚBLICA — uma única porta: get_catalog(slug)
--  Monta exatamente o formato que o catálogo (index.html) espera.
--  SECURITY DEFINER + filtros (ativa / publicado) garantem que o anônimo
--  só enxerga o que é público. Nenhuma tabela é lida direto pelo anon.
-- =============================================================================
create or replace function get_catalog(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'loja', jsonb_build_object(
      'nome', s.nome, 'sigla', s.sigla, 'bairro', s.bairro, 'whatsapp', s.whatsapp,
      'endereco', s.endereco, 'horario', s.horario, 'cor_destaque', s.cor_destaque,
      'garantia_novo', s.garantia_novo, 'garantia_seminovo', s.garantia_seminovo,
      'obs_novo', s.obs_novo, 'obs_seminovo', s.obs_seminovo
    ),
    'pagamento', jsonb_build_object(
      'repassa_juros', s.repassa_juros, 'mostrar_taxa', s.mostrar_taxa,
      'parcelas_sem_juros', s.parcelas_sem_juros, 'max_parcelas', s.max_parcelas,
      'taxas', coalesce((select jsonb_object_agg(pf.parcelas::text, pf.taxa_pct)
                         from payment_fees pf where pf.store_id = s.id), '{}'::jsonb)
    ),
    'produtos', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.slug, 'marca', p.marca, 'modelo', p.modelo, 'cam', p.cam,
          'specs', jsonb_build_object('tela', p.tela, 'chip', p.chip,
                                      'camera', p.camera, 'bateria', p.bateria),
          'cores', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'nome', c.nome, 'hex', c.hex,
                'fotos', coalesce((select jsonb_agg(ph.path order by ph.ordem)
                                   from product_photos ph where ph.color_id = c.id), '[]'::jsonb)
              ) order by c.ordem)
            from product_colors c where c.product_id = p.id), '[]'::jsonb),
          'variantes', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'gb', v.gb, 'condicao', v.condicao, 'preco_pix', v.preco_pix,
                'bateria', v.bateria, 'estado', v.estado,
                'cores', coalesce((select jsonb_agg(c2.nome order by c2.ordem)
                                   from variant_colors vc join product_colors c2 on c2.id = vc.color_id
                                   where vc.variant_id = v.id and vc.estoque > 0), '[]'::jsonb),
                'estoque', coalesce((select jsonb_object_agg(c2.nome, vc.estoque)
                                     from variant_colors vc join product_colors c2 on c2.id = vc.color_id
                                     where vc.variant_id = v.id), '{}'::jsonb)
              ) order by v.ordem, v.preco_pix)
            from variants v where v.product_id = p.id), '[]'::jsonb)
        ) order by p.ordem, p.modelo)
      from products p where p.store_id = s.id and p.publicado), '[]'::jsonb)
  )
  from stores s where s.slug = p_slug and s.ativa;
$$;

grant execute on function get_catalog(text) to anon, authenticated;

-- =============================================================================
--  STORAGE — bucket público "fotos"; só membros escrevem na pasta da loja
--  Convenção de path: "<store_id>/<produto>/<arquivo>.webp"
-- =============================================================================
insert into storage.buckets (id, name, public) values ('fotos', 'fotos', true)
  on conflict (id) do nothing;

create policy fotos_leitura on storage.objects for select
  using (bucket_id = 'fotos');

create policy fotos_escrita on storage.objects for all to authenticated
  using (bucket_id = 'fotos' and is_store_member(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'fotos' and is_store_member(((storage.foldername(name))[1])::uuid));
