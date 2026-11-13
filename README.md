# Catálogo Interativo – Loja de Celulares

Catálogo mobile em que o cliente escolhe cor, armazenamento, condição e parcelamento de um aparelho, simula o pagamento com entrada e envia a escolha pronta para o WhatsApp da loja.

## Como editar
Todos os dados ficam no objeto `LOJA`, no início do `<script>` em `index.html`:
- `loja`: nome, WhatsApp (só números, com 55 + DDD), endereço, cor de destaque, textos de garantia (`garantia_novo`, `garantia_seminovo`) e o texto que aparece embaixo da garantia (`obs_novo`, `obs_seminovo`)
- `pagamento`: taxas da maquininha por parcela (em %), parcelas sem juros, máximo de parcelas
- `produtos`: modelos, cores (com `fotos` opcionais em `img/`) e variantes (GB, condição, preço no Pix, estoque)

### Estoque
`estoque` pode ser:
- um número: total da variante, sem separar por cor (`estoque: 3`)
- um objeto por cor: `estoque: {"Azul": 1, "Preto": 2}`. Cor com 0, ou que não está no objeto, não aparece como disponível.

## Simulador de pagamento
Na tela do aparelho, o cliente pode informar uma **entrada** (Pix/dinheiro), digitando o valor ou tocando nos atalhos de 10%, 20%, 30% ou 50%. O restante vai para o cartão, e o resumo mostra:
- restante no cartão
- taxa da maquininha (% e R$) repassada para a parcela escolhida
- total no cartão, valor da parcela e total pago
- quanto ele economiza pagando tudo no Pix

A simulação vai junto na mensagem do WhatsApp.

Fórmula da taxa repassada: `total no cartão = restante ÷ (1 − taxa%)`, para a loja receber o valor cheio depois do desconto da maquininha.

## Pré-visualização do link (WhatsApp/Instagram)
Depois do deploy, troque `SEU-DOMINIO` na tag `og:image` do `index.html` pelo endereço real do site (ex.: `catalogo-loja.vercel.app`).

## Deploy na Vercel
1. Importe este repositório em vercel.com → **Add New → Project**
2. Framework: **Other**. Sem build command, output = raiz
3. Deploy

Site estático, sem dependências.
