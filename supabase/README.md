# Supabase — banco do catálogo

`schema.sql` é a modelagem completa (tabelas, integridade, RLS, função pública e Storage). Validada contra um PostgreSQL real: criação, rejeição de dados inconsistentes, `get_catalog` no formato do catálogo e políticas de acesso.

## Como aplicar (uma vez, projeto novo)
1. No projeto Supabase: **SQL Editor → New query**.
2. Cole o conteúdo de `schema.sql` e **Run**.

Isso cria 8 tabelas, a função pública `get_catalog(slug)`, o bucket `fotos` e todas as regras de segurança.

## Modelo (resumo)
- **Multi-loja** desde a base: `stores` + `store_id` em tudo.
- **Estoque por SKU** (`variant_colors` = variante × cor), não número solto.
- **Integridade pelo banco**: chaves estrangeiras compostas impedem SKU com cor de outro produto, filho com `store_id` divergente, seminovo sem bateria/estado, hex inválido, estoque negativo, cor repetida no produto.
- **Segurança (RLS)**: o público não lê tabela nenhuma; só enxerga o catálogo via `get_catalog(slug)` (que filtra loja ativa + produto publicado). O lojista autenticado (`store_members`) só mexe nos dados da própria loja. A `service_role` (migração/admin) fica apenas nas variáveis de ambiente da Vercel.

## Próximos passos (quando as chaves chegarem)
1. Criar o usuário dono (Supabase Auth) e o vínculo em `store_members`.
2. Migrar os dados do `loja.json` para as tabelas (script).
3. Catálogo passa a ler via `get_catalog`; o painel (`/admin`) ganha login e gravação.

As fotos vão para o bucket `fotos`, no caminho `<store_id>/<produto>/<arquivo>.webp`.
