# Catálogo Interativo – Loja de Celulares

Catálogo mobile em que o cliente escolhe cor, armazenamento, condição e parcelamento de um aparelho, simula o pagamento com entrada e envia a escolha pronta para o WhatsApp da loja.

## Como editar
Todos os dados ficam no arquivo **`loja.json`** (separado do código). O `index.html` carrega esse arquivo ao abrir. Estrutura:
- `loja`: nome, WhatsApp (só números, com 55 + DDD), endereço, cor de destaque, textos de garantia (`garantia_novo`, `garantia_seminovo`) e o texto que aparece embaixo da garantia (`obs_novo`, `obs_seminovo`)
- `pagamento`: taxas da maquininha por parcela (em %), parcelas sem juros, máximo de parcelas, e `mostrar_taxa` (`true`/`false`): com `false`, o resumo do cartão mostra só as parcelas e o total, sem discriminar restante/acréscimo/total no cartão
- `produtos`: modelos, cores (com `fotos` opcionais em `img/`) e variantes (GB, condição, preço no Pix, estoque)

Por ser JSON, use aspas duplas em chaves e textos, e **não** deixe vírgula sobrando no último item. Um validador avisa no console do navegador se algo estiver inconsistente (ver seção Segurança).

### Preview local
Como `loja.json` é carregado via `fetch`, abrir o `index.html` com dois cliques (`file://`) **não funciona** — o navegador bloqueia o fetch. Para testar na sua máquina, sirva a pasta por HTTP, por exemplo:
- `python -m http.server` e abra `http://localhost:8000`
- ou `npx serve`

No ar (Vercel/HTTPS) funciona normalmente, sem nenhum passo extra.

### Estoque
`estoque` pode ser:
- um número: total da variante, sem separar por cor (`estoque: 3`)
- um objeto por cor: `estoque: {"Azul": 1, "Preto": 2}`. Cor com 0, ou que não está no objeto, não aparece como disponível.

Produto com **todas** as variantes zeradas some da vitrine automaticamente (e link direto para ele volta para a vitrine) — para "pausar" um aparelho, basta zerar o estoque.

### Fotos dos produtos
A pasta `img/` é a fonte da verdade das fotos. Em vez de editar o `loja.json` na mão, basta nomear os arquivos e rodar um script.

Convenção de nome: **`<id-do-produto>-<cor>-<n>.webp`**
- `<id>`: o `id` do produto (ex.: `galaxy-s24`)
- `<cor>`: o nome da cor em minúsculas, sem acento, com espaços virando `-` (ex.: "Preto Ônix" → `preto-onix`)
- `<n>`: a ordem (1 = foto de capa)

Exemplo: `img/galaxy-s24-preto-onix-1.webp`, `...-2.webp`, `img/galaxy-s24-amarelo-ambar-1.webp`

Depois de colocar os arquivos, rode na raiz do projeto:
```
node tools/fotos.js          # atualiza o loja.json
node tools/fotos.js --dry    # só mostra o que faria, sem gravar
```
O script casa cada arquivo com o produto/cor, reescreve os campos `fotos` em ordem e avisa sobre nomes que não batem. Tirar os arquivos de uma cor remove as fotos dela (ela volta ao aparelho desenhado). Cor sem foto continua usando o desenho neutro — dá para ter só alguns modelos com foto.

Recomendações de imagem: exporte em **webp**, ~1000–1400 px no maior lado, abaixo de ~500 KB (o script avisa se passar), e use fundo claro e consistente entre as fotos. Para seminovos, fotografe o aparelho **real** — é o que o cliente quer ver.

## Simulador de pagamento
Na tela do aparelho, o cliente pode informar uma **entrada** (Pix/dinheiro), digitando o valor ou tocando nos atalhos de 10%, 20%, 30% ou 50%. O restante vai para o cartão, e o resumo mostra:
- restante no cartão
- taxa da maquininha (% e R$) repassada para a parcela escolhida
- total no cartão, valor da parcela e total pago
- quanto ele economiza pagando tudo no Pix

A simulação vai junto na mensagem do WhatsApp.

Fórmula da taxa repassada: `total no cartão = restante ÷ (1 − taxa%)`, para a loja receber o valor cheio depois do desconto da maquininha.

## Pré-visualização do link (WhatsApp/Instagram)
As tags `og:url` e `og:image` no `<head>` apontam para o domínio do deploy. Ao instalar o catálogo para outra loja, troque o domínio nessas duas tags pelo endereço real do novo site.

## Segurança e confiabilidade
- `vercel.json` define cabeçalhos de segurança (CSP, `X-Content-Type-Options`, `Referrer-Policy`, anti-clickjacking, `Permissions-Policy`, HSTS) e cache longo para `/img`. Ao usar recursos externos novos, ajuste a CSP.
- Todo dado de texto é escapado ao virar HTML e as cores passam por um sanitizador de hex — seguro mesmo que os dados venham de uma planilha editável.
- Foto que não carrega vira um aparelho neutro (sem imagem quebrada); erro ao carregar não deixa tela branca, cai num estado com link de WhatsApp.
- Ao abrir o catálogo, um validador avisa **no console do navegador** sobre dados inconsistentes (id duplicado, cor inexistente, taxa faltando, hex inválido, seminovo sem bateria/estado). Útil ao editar a loja.

## Analytics
O site usa **Vercel Web Analytics** (sem cookies, respeita a CSP — tudo same-origin). Para começar a coletar, ative uma vez no painel: **Project → Analytics → Enable Web Analytics**. Antes disso o script responde 404 e nada é coletado (sem erro para o visitante).

Além dos page views automáticos, são enviados eventos custom:
- `produto_visto` (`{ produto }`) — quais aparelhos são abertos
- `cta_whatsapp` (`{ produto, gb, cor, cond }`) — intenção de compra ao tocar em "Quero esse"
- `contato_vitrine` — toque no botão de WhatsApp da vitrine

Eventos custom têm limite mensal no plano grátis; para uma loja local, o volume fica bem abaixo disso.

## Deploy na Vercel
1. Importe este repositório em vercel.com → **Add New → Project**
2. Framework: **Other**. Sem build command, output = raiz
3. Deploy

Site estático, sem dependências.
