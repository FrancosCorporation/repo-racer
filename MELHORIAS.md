# MELHORIAS — repo-racer

> **Gerado por análise de código em 2026-10-02** · Stack: **arquivo único** (`index.html`, 251 KB) + nginx alpine (container)
> Branch `main` · base `e9755bb` · sem build step · sem CI · 3 docs de plano existentes
> **Testes executados de verdade:** container construído e subido, rotas e headers verificados por `curl`.
>
> **Este arquivo é um PLANO DE CONSOLIDAÇÃO.** O projeto já tem `MELHORIAS-3D-E-IA.md` (28 KB),
> `MELHORIAS-LOOPING.md` (16 KB) e `PLANO-DE-MELHORIAS.md` (1,6 KB). Este arquivo **não repete** o que
> lá está: aponta o que **falta**, o que os docs **divergem** e o que é **risco real de operação**.

---

## 0. Como usar este documento

1. **Leia antes**: `PLANO-DE-MELHORIAS.md` (backlog ativo, curto) e as seções de status de
   `MELHORIAS-3D-E-IA.md`. Este documento é o **complemento de segurança/operação**, não o plano geral.
2. Execute na ordem **P0 → P1 → P2 → P3**, ondas da §8.
3. **Não reescreva o jogo.** É um arquivo único de 251 KB que roda; o valor está no que funciona.
   Os itens aqui são de **operação, entrega e consistência de docs** — não de gameplay.
4. **Idioma:** português.

---

## 1. Diagnóstico executivo

Jogo de corrida 3D (three.js) com IA de rivais e boss, HUD e laço de pista. Tudo em **um** `index.html`
de 251 KB, servido por nginx em container. Sem build step, sem dependências de runtime.

**O que está bem e foi verificado em execução:**

| Item | Evidência |
|---|---|
| **Não há vazamento de `.git` no container** | `docker run --rm rr:test ls html/` → só `index.html`, `preview.png`, `LICENSE`, `50x.html` |
| **Não há segredo no código** | `grep -iE 'api_key\|secret\|token\|bearer'` em `index.html` → **nada** |
| Dependências de CDN **versionadas** | `three@0.160.0`, `@mlc-ai/web-llm@0.2.85` (não `latest`) |
| Container mínimo e limpo | `nginx:alpine`, 4 arquivos |
| Cache desativado para HTML/JS/CSS (evita stale em jogo) | `nginx.conf` (`Cache-Control: no-cache`) |
| `restart: unless-stopped` no compose | `docker-compose.yml:8` |
| Sem etapa de build → deploy é trivial | `Dockerfile:3` (comentário explica) |

**O que está quebrado (verificado):**

1. **Soft-404: todo path inexistente responde `200` com o `index.html`.** Testado:
   `GET /.git/config` → **200**, `GET /package.json` → **200** — mas o corpo é `<!DOCTYPE html>`.
   `nginx.conf` tem `try_files $uri $uri/ /index.html` no `location /`, sem `=404`.
2. **CDN sem SRI** — `integrity=` aparece **0 vezes** em 251 KB de HTML. A versão está pinada, mas
   sem `integrity` o CDN pode entregar qualquer código sob o mesmo path.
3. **Sem headers de segurança** no nginx (testado: nenhum `X-Frame-Options`/`CSP`/`nosniff`).
4. **`Server: nginx/1.31.5`** expõe a versão exata.

---

## 2. Tabela de prioridades

| ID | Título | Sev | Arquivo | Depende de |
|---|---|---|---|---|
| SEC-01 | CDN sem SRI (integridade de supply chain) | **P0** | `index.html` (tags CDN) | — |
| SEC-02 | Soft-404: qualquer path responde 200 com o jogo | **P1** | `docker/nginx.conf` | — |
| SEC-03 | Sem headers de segurança no nginx | **P1** | `docker/nginx.conf` | — |
| SEC-04 | Versão do nginx exposta (`Server:`) | **P2** | `docker/nginx.conf` | — |
| SEC-05 | `50x.html` no container sem origem no repo | **P2** | `Dockerfile:4` | — |
| BUG-01 | `PLANO-DE-MELHORIAS.md` aponta para `/tmp/rr-ai/game.mjs` (inexistente) | **P1** | `PLANO-DE-MELHORIAS.md:46` | — |
| BUG-02 | `preview.png` (288 KB) servido sem necessidade em produção | **P3** | `Dockerfile:4` | — |
| BUG-03 | Sem cache para `preview.png`/`LICENSE` (rule só cobre html/png/js/css) | **P2** | `docker/nginx.conf:9` | — |
| IMP-01 | Sem CI (build do container nem validado) | **P2** | *(ausente)* | — |
| IMP-02 | Sem `healthcheck` no container | **P2** | `docker-compose.yml` | — |
| IMP-03 | `index.html` de 251 KB monolítico, sem divisibilidade | **P3** | `index.html` | — |
| DEVOPS-01 | Imagem base `nginx:alpine` sem pin | **P2** | `Dockerfile:1` | — |
| DEVOPS-02 | Compose sem `read_only`/`cap_drop` | **P3** | `docker-compose.yml` | — |
| DOC-01 | Três docs de plano sem índice (qual está vigente?) | **P2** | `*.md` | — |
| DOC-02 | Working tree sujo com mudanças não commitadas | **P1** | `git status` | — |
| DOC-03 | Falta `SECURITY.md` | **P3** | *(ausente)* | — |

**Placar: 1 P0 · 4 P1 · 7 P2 · 3 P3 = 15 itens.**

---

## 3. Segurança
### SEC-01 · CDN sem SRI (integridade de supply chain) · [P0]

- **Arquivo:** `index.html` (tags `<script>`/`<link>` que apontam para `cdn.jsdelivr.net` e `esm.run`)
- **Evidência:** verificado por `grep -c 'integrity=' index.html` → **0** ocorrências em 251 KB.
  As dependências são `three@0.160.0` e `@mlc-ai/web-llm@0.2.85` (**versionadas** — bom).
- **Impacto:** sem `integrity`, o pin de versão **não garante integridade**: o CDN pode entregar
  qualquer conteúdo sob o mesmo path (comprometimento de conta upstream, ou resposta adulterada em
  rota intermediária). Como o jogo **executa** esse código no browser de todos os visitantes, e há
  `web-llm` (WASM, ~300 KB) carregado de fora, o impacto é execução de código arbitrário no
  navegador de quem joga. Risco clássico de supply chain de front-end.
- **Mudança:** (1) adicionar `integrity="sha384-..."` (ou `sha256-`) + `crossorigin="anonymous"` nas
  tags CDN — gerar o hash com `curl -s <url> | openssl dgst -sha384 -binary | openssl base64 -A`;
  (2) alternativa mais forte (se quiser eliminar a dependência externa): **vendorizar** `three.js` e
  `web-llm` para dentro do repo e servir local — o jogo já é 100% estático, então isso é coerente e
  remove a dependência de rede por completo; (3) registrar os hashes num commentário para revisão.
- **Aceite:** as tags CDN têm `integrity` (ou as libs estão vendorizadas e não há CDN).
- **Verificação:**
  ```bash
  grep -c 'integrity=' index.html    # >= 1 (por tag CDN)
  # se vendorizar:
  grep -c 'cdn.jsdelivr\|esm.run' index.html   # 0
  ```

### SEC-02 · Soft-404: qualquer path responde 200 com o jogo · [P1]

- **Arquivo:** `docker/nginx.conf` (`location /` → `try_files $uri $uri/ /index.html`)
- **Evidência:** verificado **em execução** (container construído e subido):
  ```
  GET /.git/config -> 200   (corpo: <!DOCTYPE html>, Content-Type: text/html)
  GET /package.json -> 200  (corpo: <!DOCTYPE html>)
  ```
  Importante: **não** é vazamento — o `Dockerfile:4` copia apenas `index.html preview.png LICENSE`, e o
  container contém só esses arquivos (`docker run --rm rr:test ls html/` confirmado). É o **fallback
  SPA** que devolve o jogo para qualquer path.
- **Impacto:** (a) **monitoramento/segurança**: todo path inexistente responde `200`, então um scanner
  de vulnerabilidade, um WAF ou um teste de health-check **não distingue** "existe" de "não existe" —
  falsos negativos em detecção; (b) **SEO/analítica**: paths errados indexados como páginas válidas;
  (c) `robots.txt`/`favicon.ico` ausentes também retornam o HTML com `200`.
- **Mudança:** decidir explicitamente: (1) **jogo único** (SPA): manter o fallback, mas responder
  `200` **apenas** para paths de navegação e usar `404` real para caminhos com extensão (ex.: `/\.json$`,
  `/\.js$` → 404) — e adicionar `robots.txt`; ou (2) **estático puro**: trocar por
  `try_files $uri $uri/ =404;` e remover o fallback (o jogo abre em `/` de qualquer forma, já que é
  um arquivo só).
- **Aceite:** `/.git/config` e `/package.json` respondem **404**; `/` e rotas do jogo respondem `200`.
- **Verificação:**
  ```bash
  docker build -t rr:test . && docker run -d --name rrtest -p 8091:80 rr:test
  for p in /.git/config /package.json /robots.txt /; do
    curl -s -o /dev/null -w "$p -> %{http_code}\n" --max-time 4 "http://localhost:8091$p"
  done
  docker rm -f rrtest
  ```

### SEC-03 · Sem headers de segurança no nginx · [P1]

- **Arquivo:** `docker/nginx.conf`
- **Evidência:** verificado em execução — `curl -sI http://localhost:8091/` → **nenhum** header de
  segurança (sem `X-Frame-Options`, `Content-Security-Policy`, `X-Content-Type-Options`,
  `Strict-Transport-Security`).
- **Impacto:** o jogo pode ser **embutido** em qualquer site (clickjacking); sem `nosniff`, um asset
  pode ser interpretado como outro tipo; sem CSP, qualquer injeção futura no HTML roda sem restrição.
  Como o jogo carrega WASM (`web-llm`) e `eval`-free é a prática, o CSP com `wasm-unsafe-eval` é
  obrigatório para não quebrar.
- **Mudança:** adicionar ao `server {}`:
  ```nginx
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header Referrer-Policy "no-referrer" always;
  add_header Content-Security-Policy "default-src 'self'; script-src 'self' https://cdn.jsdelivr.net https://esm.run 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self' https://cdn.jsdelivr.net https://esm.run; img-src 'self' data: blob:;" always;
  ```
  (ajustar `script-src`/`connect-src` ao que for vendorizado no `SEC-01`).
- **Aceite:** respostas trazem os 4 headers; **o jogo ainda carrega** (three.js + web-llm WASM).
- **Verificação:**
  ```bash
  curl -sI --max-time 4 http://localhost:8091/ | grep -iE 'x-frame|content-security|x-content-type'
  # e abrir no browser: jogo carrega, sem erro de CSP no console
  ```

### SEC-04 · Versão do nginx exposta · [P2]

- **Arquivo:** `docker/nginx.conf` (não define `server_tokens`)
- **Evidência:** verificado: `curl -sI` → `Server: nginx/1.31.5` (versão **exata**).
- **Impacto:** baixo isoladamente, mas facilita o reconhecimento automático de versão vulnerável. É
  um item de 30 segundos.
- **Mudança:** `server_tokens off;` no bloco `server` (some a versão; o header `Server: nginx` continua).
- **Aceite:** `curl -sI` mostra `Server: nginx` sem versão.
- **Verificação:**
  ```bash
  curl -sI --max-time 4 http://localhost:8091/ | grep -i '^server'   # sem 1.31.5
  ```

### SEC-05 · `50x.html` no container sem origem no repo · [P2]

- **Arquivo:** `Dockerfile:4`
- **Evidência:** o container em execução tem `50x.html` em `/usr/share/nginx/html/`, mas
  `ls` no repositório **não mostra** `50x.html` — ele não é `COPY` explicitamente, então vem de
  alguma camada anterior ou foi adicionado localmente e não commitado.
- **Impacto:** arquivo **não rastreado** dentro do artefato de produção — o que o build entrega não
  corresponde ao que está no git. Dificulta reproduzir o container exatamente.
- **Mudança:** (1) rastrear `50x.html` no repo **ou** removê-lo do build; (2) garantir que o
  `Dockerfile` lista **exatamente** os arquivos que o repo contém (build reprodutível).
- **Aceite:** os arquivos no container = os arquivos no repo; `git status` limpo após o build.
- **Verificação:**
  ```bash
  docker run --rm rr:test ls /usr/share/nginx/html/     # compara com git ls-files
  git status --porcelain                               # limpo
  ```
---

## 4. Bugs e defeitos funcionais

### BUG-01 · Plano aponta para caminho inexistente (`/tmp/rr-ai/game.mjs`) · [P1]

- **Arquivo:** `PLANO-DE-MELHORIAS.md:46`
- **Evidência:**
  ```bash
  # Verificar sintaxe
  node --check /tmp/rr-ai/game.mjs
  ```
  O jogo **é** `index.html` (arquivo único) — não existe `game.mjs` no repo, e `/tmp` não sobrevive
  a reboot. Verificado: `find . -name '*.mjs'` → nada.
- **Impacto:** o comando de verificação do backlog **não roda** — quem seguir o plano recebe
  "Cannot find module" e não sabe o que fazer. Como é o plano **ativo** (o único curto e com status),
  é o primeiro que alguém executa.
- **Mudança:** (1) corrigir para o comando real: `node --check` não se aplica a HTML; usar
  ```bash
  # verificar sintaxe do script embutido:
  sed -n '/<script>/,/<\/script>/p' index.html | sed '1d;$d' > /tmp/game.mjs && node --check /tmp/game.mjs
  # ou abrir o jogo e conferir o console (sem erro de sintaxe)
  ```
  (2) ou, mais simples, remover o comando e usar o teste de carregamento via browser;
  (3) **garantir que o caminho não depende de `/tmp`**.
- **Aceite:** o comando de verificação do plano **roda** e retorna 0.
- **Verificação:**
  ```bash
  grep -n 'rr-ai/game.mjs' PLANO-DE-MELHORIAS.md && echo 'FALHA: caminho inexistente' || echo OK
  ```

### BUG-02 · `preview.png` (288 KB) no container sem função em produção · [P3]

- **Arquivo:** `Dockerfile:4`
- **Evidência:** `COPY index.html preview.png LICENSE /usr/share/nginx/html/` — `preview.png`
  (288 KB) é a imagem de preview do repositório (aparece no README do GitHub), não usada pelo jogo.
- **Impacto:** 288 KB desnecessários na imagem, servidos em `/preview.png` (confirmado `200`).
  Menor, mas é lixo em produção.
- **Mudança:** remover `preview.png` do `Dockerfile` (manter no repo para o README); servindo o jogo,
  a imagem de preview não é necessária.
- **Aceite:** `/preview.png` não responde mais; a imagem do repo continua no GitHub (é outro caminho).
- **Verificação:**
  ```bash
  docker run --rm rr:test ls /usr/share/nginx/html/   # sem preview.png
  ```

### BUG-03 · Cache não cobre `LICENSE` e favicon · [P2]

- **Arquivo:** `docker/nginx.conf:9`
- **Evidência:** a regra de cache é `location ~* \.(html|png|js|css)$` → `no-cache`. Não cobre
  `.ico`, `.json`, `.webmanifest`, e o `LICENSE` (sem extensão) cai no `location /` (fallback SPA).
- **Impacto:** (a) favicon/manifesto podem receber **fallback HTML** com `Content-Type: text/html` —
  o navegador tenta interpretar o `index.html` como ícone e **não mostra ícone**; (b) `LICENSE`
  servido como HTML em vez de texto.
- **Mudança:** (1) adicionar `location = /favicon.ico { try_files $uri =404; }` e um `favicon.ico`
  real; (2) garantir que arquivos sem extensão (`/LICENSE`) sirvam como arquivo, não como fallback.
- **Aceite:** `/favicon.ico` → `200` com `image/x-icon` (ou 404 limpo); `/LICENSE` → texto.
- **Verificação:**
  ```bash
  curl -sI --max-time 4 http://localhost:8091/favicon.ico | grep -i content-type
  curl -s --max-time 4 http://localhost:8091/LICENSE | head -c 40
  ```

---

## 5. Qualidade, documentação e consistência

### IMP-01 · Sem CI (nem o build do container é validado) · [P2]

- **Arquivo:** *(ausente)* `.github/workflows/`
- **Evidência:** sem workflow. O único "build" é manual (`docker build`).
- **Impacto:** nada garante que o container constrói, nem que o jogo não quebrou de sintaxe. Como é
  um arquivo único de 251 KB, um erro de sintaxe JS passa despercebido até alguém abrir o jogo.
- **Mudança:** `ci.yml` com: (1) `docker build` (garante que a imagem constrói); (2) extrair o
  `<script>` e rodar `node --check` (garante sintaxe); (3) opcionalmente, `curl` no container para
  confirmar `200` em `/`.
- **Aceite:** PR com erro de sintaxe no JS **ou** Dockerfile quebrado é bloqueado.
- **Verificação:**
  ```bash
  docker build -t rr:test .
  sed -n '/<script>/,/<\/script>/p' index.html | sed '1d;$d' > /tmp/g.mjs && node --check /tmp/g.mjs
  ```

### IMP-02 · Sem healthcheck no container · [P2]

- **Arquivo:** `docker-compose.yml`
- **Evidência:** `restart: unless-stopped` e `ports`, mas **sem `healthcheck`**.
- **Impacto:** o orquestrador considera o container "são" desde que o processo do nginx esteja de pé —
  não valida que o jogo é servido corretamente. Um nginx que responde 502/404 por config errada fica
  "saudável".
- **Mudança:** adicionar
  ```yaml
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost/", "--spider"]
    interval: 30s
    timeout: 3s
    retries: 3
  ```
- **Aceite:** `docker inspect` mostra `Health: healthy`; unhealthy quando o jogo não serve.
- **Verificação:**
  ```bash
  docker inspect --format '{{.State.Health.Status}}' repo-racer
  ```

### IMP-03 · `index.html` monolítico de 251 KB · [P3]

- **Arquivo:** `index.html`
- **Evidência:** 251 KB em um arquivo (verificado: `curl .../ | wc -c` → `251419`).
- **Impacto:** diff ilegível (qualquer mudança muda o arquivo inteiro), sem cache granular por módulo,
  e **sem SRI possível por arquivo local** sem reescrever.
- **Mudança:** **não** é urgente (o jogo funciona). Se for escolhido: extrair o JS para `game.js`
  (o que também permite `Cache-Control` de longa duração e cache granular). Só depois que o resto
  estiver estável — é refactor, não correção.
- **Aceite:** (se feito) o jogo roda **igual** ao de antes, com o JS em arquivo separado e cacheável.
- **Verificação:** (se feito) `ls *.js` mostra `game.js` e o jogo **continua igual** no browser.

---

## 6. Documentação

### DOC-01 · Três docs de plano sem índice (qual está vigente?) · [P2]

- **Arquivo:** `MELHORIAS-3D-E-IA.md` (28 KB), `MELHORIAS-LOOPING.md` (16 KB), `PLANO-DE-MELHORIAS.md` (1,6 KB)
- **Evidência:** três documentos com sobreposição e sem indicador de qual é o vigente. O
  `PLANO-DE-MELHORIAS.md` tem "Status Atual (01/10/2026)" e backlog — parece o ativo; os outros dois
  são grandes e de fases anteriores.
- **Impacto:** quem chega não sabe por onde começar; itens podem ser **re-feitos** ou **perdidos**
  entre docs (o mesmo modo de falha de `site_corp`, que tem 11 docs — e por isso lá o item é `DOC-01`).
- **Mudança:** (1) `README.md` (ou topo do `PLANO-DE-MELHORIAS.md`) com uma tabela: documento →
  assunto → status (ativo/arquivado); (2) marcar os dois grandes como **histórico** e o curto como
  **ativo**; (3) este `MELHORIAS.md` entra na tabela como "operação/segurança".
- **Aceite:** um índice na raiz diz qual ler primeiro.
- **Verificação:** `grep -n 'MELHORIAS' README.md` mostra a tabela.

### DOC-02 · Working tree sujo · [P1]

- **Arquivo:** `git status` → `M index.html`, `M README.md`, `M MELHORIAS-3D-E-IA.md`, `?? PLANO-DE-MELHORIAS.md`
- **Evidência:** 4 arquivos modificados/novos **não commitados**, incluindo o `index.html` de 251 KB
  (o jogo em si) e o plano ativo.
- **Impacto:** o jogo que roda **não é** o que está no git. Se a máquina formatar, perde-se o estado
  real; e a mudança não é auditável.
- **Mudança:** revisar os diffs e **commitar** (`feat:`/`docs:`), separando jogo de docs.
- **Aceite:** `git status --porcelain` limpo.
- **Verificação:**
  ```bash
  git status --porcelain | wc -l   # 0
  ```

### DOC-03 · Falta `SECURITY.md` · [P3]

- **Arquivo:** *(ausente)* `SECURITY.md`
- **Evidência:** tem `LICENSE` e README, sem guia de reporte.
- **Impacto:** baixo (jogo estático, sem servidor de lógica), mas o `SEC-01` (supply chain do CDN) é
  um tema que deveria ficar registrado.
- **Mudança:** criar com canal + a nota "dependências de CDN pinadas; SRI em andamento" (linkando `SEC-01`).
- **Aceite:** arquivo existe.
- **Verificação:** `ls SECURITY.md`

---

## 7. DevOps / Infra

### DEVOPS-01 · Pin da imagem base do nginx · [P2]

- **Arquivo:** `Dockerfile:1`
- **Evidência:** `FROM nginx:alpine` — tag **sem versão**.
- **Impacto:** (a) **não-reprodutibilidade**: o mesmo `docker build` em datas diferentes traz nginx
  diferente (foi o que trouxe `1.31.5` na versão testada — pode mudar a qualquer momento);
  (b) **supply chain**: `nginx:alpine` é tag móvel; um movimento de tag (ou conta upstream
  comprometida) muda o código que serve o jogo.
- **Mudança:** pinar por tag de versão (`nginx:1.31.5-alpine`) ou, melhor, por **digest**
  (`nginx@sha256:...`); registrar o digest no repositório.
- **Aceite:** rebuild 30 dias depois usa a mesma imagem base.
- **Verificação:**
  ```bash
  grep '^FROM' Dockerfile                      # deve ter versao ou digest
  docker inspect --format '{{index .RepoDigests 0}}' nginx:alpine   # ver digest
  ```

### DEVOPS-02 · Compose sem `read_only`/limites · [P3]

- **Arquivo:** `docker-compose.yml`
- **Evidência:** só `build`, `ports`, `restart`. Sem `read_only`, `security_opt`, `mem_limit` ou
  `cap_drop`.
- **Impacto:** baixo (nginx estático é inofensivo), mas `cap_drop: ALL` + `read_only: true` é
  hardening padrão de container web e custa 2 linhas.
- **Mudança:** adicionar `read_only: true`, `security_opt: [no-new-privileges:true]`,
  `cap_drop: [ALL]` (nginx roda bem sem capabilities nesse setup estático).
- **Aceite:** container sobe com essas restrições e `/` continua `200`.
- **Verificação:**
  ```bash
  docker run --rm -d --name rrtest -p 8091:80 --read-only --cap-drop ALL rr:test && sleep 2
  curl -s -o /dev/null -w '%{http_code}
' http://localhost:8091/   # 200
  docker rm -f rrtest
  ```

---

## 8. Ordem de execução (waves)

### Wave 1 — Supply chain e correção do plano (P0/P1)
1. **`SEC-01`** — SRI nas tags CDN **ou** vendorizar `three.js`/`web-llm`.
2. **`BUG-01`** — corrigir o comando de verificação do plano ativo (hoje não roda).
3. **`DOC-02`** — commitar as mudanças pendentes (o jogo que roda ≠ o do git).

### Wave 2 — Operação do container (P1)
4. **`SEC-02`** — decidir o fallback: `=404` para paths com extensão (ou remover o fallback SPA).
5. **`SEC-03`** — headers de segurança no nginx (com `wasm-unsafe-eval` no CSP).
6. **`BUG-03`** — favicon/`LICENSE` servidos corretamente (não como fallback HTML).

### Wave 3 — Reprodução (P2)
7. **`SEC-05`** — build reproduzível (rastrear/remover `50x.html`).
8. **`SEC-04`** — `server_tokens off`.
9. **`IMP-01`** — CI (build + sintaxe do JS embutido).
10. **`IMP-02`** — healthcheck no compose.
11. **`DOC-01`** — índice dos três docs.

### Wave 4 — Polimento (P3)
12. **`BUG-02`** (remover `preview.png` do container), **`IMP-03`** (dividir o HTML), **`DOC-03`**.

**Dependências que não podem ser invertidas:**
`SEC-01` antes de `SEC-03` (o CSP lista `script-src` conforme o que for vendorizado) ·
`SEC-02` antes de `BUG-03` (definir o fallback primeiro, depois os assets especiais) ·
`DOC-02` é o primeiro de todos — **commitar antes de mexer** em qualquer coisa, senão o trabalho
novo se mistura com o que já estava em andamento.

---

## 9. Fora de escopo / riscos

| Item | Decisão | Motivo |
|---|---|---|
| Reescrever o jogo / dividir o HTML agora | **Não** | `IMP-03` é refactor de risco sem ganho de segurança; o jogo funciona. Só depois de estável. |
| Trocar three.js por motor próprio | **Nunca** | three.js pinado é o correcto; o problema é SRI, não a lib. |
| Remover o fallback SPA | **Só com decisão consciente** | O jogo é de arquivo único, então `/` funciona sem fallback — mas remover muda o comportamento de rotas (ver `SEC-02`). |
| Adicionar backend / ranking online | **Não** | Mudaria a natureza do projeto (hoje é 100% estático, sem servidor). |
| Otimizar performance de render | **Não aqui** | É o escopo de `MELHORIAS-3D-E-IA.md`, não deste documento. |

**Riscos desta execução:**

- **`SEC-01` (vendorizar) aumenta o repo** (`web-llm` tem ~300 KB de WASM) e exige decidir a licença
  (MIT — ok para redistribuir) e o `Content-Type` do `.wasm` no nginx. A alternativa (só SRI) é
  **muito mais leve** e resolve — prefira começar por ela.
- **`SEC-02` pode quebrar rotas do jogo** se o jogo usar history API (`/game/x`). Como é arquivo único,
  provavelmente não usa — mas **verifique no `index.html`** antes de remover o fallback.
- **`SEC-03` (CSP) pode quebrar o WASM** se faltar `wasm-unsafe-eval` ou o `connect-src` do modelo.
  Teste **no browser** (o jogo baixa `web-llm` na primeira execução), não só o header.
- **`DOC-02` (commitar) mistura** o trabalho em andamento (loops/visual, pelos commits recentes) com
  o que vier agora. Faça commit **antes** de começar, com mensagem coerente com o histórico.

---

## 10. Definição de pronto (DoD)

**Segurança**
- [ ] `SEC-01` — tags CDN com `integrity` (ou libs vendorizadas, sem CDN)
- [ ] `SEC-02` — `/.git/config` e `/package.json` → **404** (não soft-200)
- [ ] `SEC-03` — `X-Frame-Options`, `CSP`, `nosniff`, `Referrer-Policy` presentes; jogo **funciona**
- [ ] `SEC-04` — `Server:` sem número de versão
- [ ] `SEC-05` — arquivos no container = arquivos no repo

**Funcional**
- [ ] `BUG-01` — comando de verificação do plano **roda** (não aponta para `/tmp`)
- [ ] `BUG-02` — `preview.png` fora do container
- [ ] `BUG-03` — `/favicon.ico` com `image/x-icon`; `/LICENSE` como texto

**Qualidade e operação**
- [ ] `IMP-01` — CI faz `docker build` + `node --check` do JS embutido
- [ ] `IMP-02` — healthcheck ativo (`docker inspect` → `healthy`)
- [ ] `IMP-03` — (P3) HTML dividido, se decidido

**Documentação**
- [ ] `DOC-01` — índice dos docs na raiz
- [ ] `DOC-02` — `git status` limpo
- [ ] `DEVOPS-01` — imagem base pinada (tag/digest)
- [ ] `DEVOPS-02` — container com `read_only` + `cap_drop`
- [ ] `DOC-03` — `SECURITY.md`

**Validação final:**
```bash
docker build -t rr:test .
docker run -d --name rrtest -p 8091:80 rr:test && sleep 3
curl -s -o /dev/null -w '/ -> %{http_code}\n' http://localhost:8091/
curl -s -o /dev/null -w '/.git/config -> %{http_code}\n' http://localhost:8091/.git/config   # 404
curl -sI http://localhost:8091/ | grep -iE 'content-security|x-frame-options'
docker rm -f rrtest
git status --porcelain   # 0
```

---

*Fim do plano. Gerado por leitura do código **e execução real** (container construído, subido e
testado por `curl`) em 2026-10-02. Consolida `MELHORIAS-3D-E-IA.md`, `MELHORIAS-LOOPING.md` e
`PLANO-DE-MELHORIAS.md` — que **não** foram repetidos aqui.*
