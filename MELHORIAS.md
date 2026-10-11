# MELHORIAS — repo-racer

> **Diagnóstico-base de 2026-10-02** · Stack: **arquivo único** (`index.html`) + Nginx em container.
> Os testes citados no histórico abaixo são daquela análise-base; não representam validação das mudanças de 11/10/2026.
>
> **Este arquivo é um PLANO DE CONSOLIDAÇÃO.** O projeto já tem `MELHORIAS-3D-E-IA.md` (28 KB),
> `MELHORIAS-LOOPING.md` (16 KB) e `PLANO-DE-MELHORIAS.md` (1,6 KB). Este arquivo **não repete** o que
> lá está: aponta o que **falta**, o que os docs **divergem** e o que é **risco real de operação**.

> **Estado em 11/10/2026:** SRI no import map, Nginx estrito, Docker/Compose endurecidos, workflow de CI,
> `.gitignore`, `SECURITY.md` e índice dos documentos foram implementados. Falta aceite em navegador/container
> e publicar/executar o workflow. Comandos locais e porta publicada no Compose usam bind em `127.0.0.1`.
> A rodada também preserva melhorias de jogo em andamento descritas no README.

---

## 0. Como usar este documento

1. **Leia antes**: `PLANO-DE-MELHORIAS.md` (backlog ativo, curto) e as seções de status de
   `MELHORIAS-3D-E-IA.md`. Este documento é o **complemento de segurança/operação**, não o plano geral.
2. Use a §10 para distinguir implementação de aceite pendente; a ordem original está registrada na §8.
3. O arquivo único permanece intencional. As melhorias de gameplay e experiência estão descritas no README
   e no histórico `MELHORIAS-3D-E-IA.md`.
4. **Idioma:** português.

---

## 1. Diagnóstico executivo

Jogo de corrida 3D (three.js) com IA de rivais e boss, HUD e laço de pista. O jogo segue em um `index.html`,
servido opcionalmente por Nginx em container. Sem build step.

**Diagnóstico da execução-base em 2026-10-02 (histórico):**

| Item | Evidência |
|---|---|
| **Não há vazamento de `.git` no container** | `docker run --rm rr:test ls html/` → só `index.html`, `preview.png`, `LICENSE`, `50x.html` |
| **Não há segredo no código** | `grep -iE 'api_key\|secret\|token\|bearer'` em `index.html` → **nada** |
| Dependências de CDN **versionadas** | `three@0.160.0`, `@mlc-ai/web-llm@0.2.85` (não `latest`) |
| Container mínimo e limpo | `nginx:alpine`, 4 arquivos |
| Cache desativado para HTML/JS/CSS (evita stale em jogo) | `nginx.conf` (`Cache-Control: no-cache`) |
| `restart: unless-stopped` no compose | `docker-compose.yml:8` |
| Sem etapa de build → deploy é trivial | `Dockerfile:3` (comentário explica) |

**Problemas encontrados naquele diagnóstico e endereçados no código nesta rodada:**

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
| SEC-01 | Imports CDN sem SRI (integridade de supply chain) | **P0** | `index.html` (import map + import dinâmico) | — |
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

**Inventário original:** 15 itens (prioridades mantidas para rastreabilidade). Consulte a §10 para o estado atual.

---

## 3. Segurança
### SEC-01 · Imports CDN sem SRI (integridade de supply chain) · [P0]

- **Arquivo:** `index.html` (import map do Three.js e import dinâmico de WebLLM)
- **Evidência inicial:** havia 0 hashes SRI. As URLs apontam a `three@0.160.0` e
  `@mlc-ai/web-llm@0.2.85`; o pin de versão não verificava os bytes entregues.
- **Impacto:** sem `integrity`, o pin de versão **não garante integridade**: o CDN pode entregar
  qualquer conteúdo sob o mesmo path (comprometimento de conta upstream, ou resposta adulterada em
  rota intermediária). Como o jogo **executa** esse código no browser de todos os visitantes, e há
  `web-llm` (WASM, ~300 KB) carregado de fora, o impacto é execução de código arbitrário no
  navegador de quem joga. Risco clássico de supply chain de front-end.
- **Mudança aplicada:** a propriedade `integrity` do import map fixa SHA-384 para o núcleo e o grafo
  completo de módulos Three.js usados no jogo, além do bundle WebLLM importado dinamicamente. Se mudar
  uma URL/version, baixe a resposta daquela URL, recalcule o SHA-384 e atualize o mapa junto dela.
- **Aceite:** cada URL CDN importada pelo documento possui hash para os bytes exatos retornados.
- **Verificação:**
  ```bash
  # Revise a chave integrity do import map; não procure atributo HTML integrity.
  rg -n 'sha384-' index.html
  ```
  **Aceite no navegador ainda pendente:** confirme que a cena e o modo LLM carregam e que uma
  resposta CDN com byte alterado é recusada. O modo LLM baixa pesos apenas se o jogador o ativar.

### SEC-02 · Soft-404: qualquer path responde 200 com o jogo · [P1]

- **Arquivo:** `docker/nginx.conf` (configuração inicial usava fallback para `/index.html`)
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
- **Mudança aplicada:** a raiz serve explicitamente `/index.html`; os demais caminhos usam
  `try_files $uri =404;`. Não há rotas internas no jogo.
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
- **Mudança aplicada:** `docker/nginx.conf` define `nosniff`, `SAMEORIGIN`, `no-referrer`, uma
  `Permissions-Policy` restritiva e CSP com `wasm-unsafe-eval`, workers Blob e origens usadas por
  Three.js/WebLLM e pelos downloads de pesos Hugging Face. A compatibilidade do CSP em execução
  ainda precisa de confirmação no navegador.
- **Aceite:** respostas trazem os 4 headers; **o jogo ainda carrega** (three.js + web-llm WASM).
- **Verificação:**
  ```bash
  curl -sI --max-time 4 http://localhost:8091/ | grep -iE 'x-frame|content-security|x-content-type'
  # e abrir no browser: jogo carrega, sem erro de CSP no console
  ```

### SEC-04 · Versão do nginx exposta · [P2]

- **Arquivo:** `docker/nginx.conf` (a configuração inicial não definia `server_tokens`)
- **Evidência histórica:** em 2026-10-02, `curl -sI` mostrou `Server: nginx/1.31.5`.
- **Impacto:** baixo isoladamente, mas facilita o reconhecimento automático de versão vulnerável. É
  um item de 30 segundos.
- **Mudança aplicada:** `server_tokens off;` em `docker/nginx.conf` (some a versão; o header `Server: nginx` continua).
- **Aceite:** `curl -sI` mostra `Server: nginx` sem versão.
- **Verificação:**
  ```bash
  curl -sI --max-time 4 http://localhost:8091/ | grep -i '^server'   # sem 1.31.5
  ```

### SEC-05 · `50x.html` no container sem origem no repo · [P2]

- **Arquivo:** `Dockerfile`
- **Evidência:** o container em execução tem `50x.html` em `/usr/share/nginx/html/`, mas
  `ls` no repositório **não mostra** `50x.html` — ele não é `COPY` explicitamente, então vem de
  alguma camada anterior ou foi adicionado localmente e não commitado.
- **Impacto:** arquivo **não rastreado** dentro do artefato de produção — o que o build entrega não
  corresponde ao que está no git. Dificulta reproduzir o container exatamente.
- **Mudança aplicada:** Dockerfile copia somente `index.html` e `LICENSE`, e remove o `50x.html`
  herdado da imagem base.
- **Aceite:** os arquivos no container = os arquivos no repo; `git status` limpo após o build.
- **Verificação:**
  ```bash
  docker run --rm rr:test ls /usr/share/nginx/html/     # compara com git ls-files
  git status --porcelain                               # limpo
  ```
---

## 4. Bugs e defeitos funcionais

### BUG-01 · Plano aponta para caminho inexistente (`/tmp/rr-ai/game.mjs`) · [P1]

- **Arquivo:** `PLANO-DE-MELHORIAS.md` (versão anterior)
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
- **Mudança aplicada:** `PLANO-DE-MELHORIAS.md` foi reescrito sem o caminho `/tmp/rr-ai/game.mjs`;
  o CI extrai o módulo embutido para `/tmp` somente durante o job e roda `node --check` nele.
- **Aceite:** o comando de verificação do plano **roda** e retorna 0.
- **Verificação:**
  ```bash
  grep -n 'rr-ai/game.mjs' PLANO-DE-MELHORIAS.md && echo 'FALHA: caminho inexistente' || echo OK
  ```

### BUG-02 · `preview.png` (288 KB) no container sem função em produção · [P3]

- **Arquivo:** `Dockerfile`
- **Evidência:** `COPY index.html preview.png LICENSE /usr/share/nginx/html/` — `preview.png`
  (288 KB) é a imagem de preview do repositório (aparece no README do GitHub), não usada pelo jogo.
- **Impacto:** 288 KB desnecessários na imagem, servidos em `/preview.png` (confirmado `200`).
  Menor, mas é lixo em produção.
- **Mudança aplicada:** `preview.png` permanece no repositório para o README e saiu do Dockerfile.
- **Aceite:** `/preview.png` não responde mais; a imagem do repo continua no GitHub (é outro caminho).
- **Verificação:**
  ```bash
  docker run --rm rr:test ls /usr/share/nginx/html/   # sem preview.png
  ```

### BUG-03 · Cache não cobre `LICENSE` e favicon · [P2]

- **Arquivo:** `docker/nginx.conf`
- **Evidência:** a regra de cache é `location ~* \.(html|png|js|css)$` → `no-cache`. Não cobre
  `.ico`, `.json`, `.webmanifest`, e o `LICENSE` (sem extensão) cai no `location /` (fallback SPA).
- **Impacto:** (a) favicon/manifesto podem receber **fallback HTML** com `Content-Type: text/html` —
  o navegador tenta interpretar o `index.html` como ícone e **não mostra ícone**; (b) `LICENSE`
  servido como HTML em vez de texto.
- **Mudança aplicada:** `/LICENSE` tem `Content-Type: text/plain`; `/favicon.ico` ausente e caminhos
  sem arquivo retornam 404, sem receber o HTML do jogo.
- **Aceite:** `/favicon.ico` → `200` com `image/x-icon` (ou 404 limpo); `/LICENSE` → texto.
- **Verificação:**
  ```bash
  curl -sI --max-time 4 http://localhost:8091/favicon.ico | grep -i content-type
  curl -s --max-time 4 http://localhost:8091/LICENSE | head -c 40
  ```

---

## 5. Qualidade, documentação e consistência

### IMP-01 · Sem CI (nem o build do container é validado) · [P2]

- **Arquivo:** `.github/workflows/ci.yml`
- **Evidência inicial:** não havia workflow; o único "build" era manual (`docker build`).
- **Impacto:** nada garante que o container constrói, nem que o jogo não quebrou de sintaxe. Como é
  um arquivo único de 251 KB, um erro de sintaxe JS passa despercebido até alguém abrir o jogo.
- **Mudança aplicada:** `.github/workflows/ci.yml` extrai o módulo embutido e roda `node --check`, depois
  constrói a imagem Docker. O workflow ainda não foi executado no GitHub.
- **Aceite:** PR com erro de sintaxe no JS **ou** Dockerfile quebrado é bloqueado.
- **Verificação:**
  ```bash
  docker build -t rr:test .
  sed -n '/<script>/,/<\/script>/p' index.html | sed '1d;$d' > /tmp/g.mjs && node --check /tmp/g.mjs
  ```

### IMP-02 · Sem healthcheck no container · [P2]

- **Arquivo:** `docker-compose.yml`
- **Evidência inicial:** `restart: unless-stopped` e `ports`, mas **sem `healthcheck`**.
- **Impacto:** o orquestrador considera o container "são" desde que o processo do nginx esteja de pé —
  não valida que o jogo é servido corretamente. Um nginx que responde 502/404 por config errada fica
  "saudável".
- **Mudança aplicada:** `docker-compose.yml` inclui
  ```yaml
  healthcheck:
    test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1/"]
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
- **Evidência histórica:** o documento tinha 251 KB na análise de 2026-10-02.
- **Impacto:** diffs maiores e sem cache granular por módulo.
- **Mudança:** **não** é urgente (o jogo funciona). Se for escolhido: extrair o JS para `game.js`
  (o que também permite `Cache-Control` de longa duração e cache granular). Só depois que o resto
  estiver estável — é refactor, não correção.
- **Aceite:** (se feito) o jogo roda **igual** ao de antes, com o JS em arquivo separado e cacheável.
- **Verificação:** (se feito) `ls *.js` mostra `game.js` e o jogo **continua igual** no browser.

---

## 6. Documentação

### DOC-01 · Três docs de plano sem índice (qual está vigente?) · [P2]

- **Arquivo:** `README.md` e documentos de melhorias
- **Evidência inicial:** havia documentos com sobreposição e sem indicador de qual era o vigente. O
  `PLANO-DE-MELHORIAS.md` tem "Status Atual (01/10/2026)" e backlog — parece o ativo; os outros dois
  são grandes e de fases anteriores.
- **Impacto:** quem chega não sabe por onde começar; itens podem ser **re-feitos** ou **perdidos**
  entre docs (o mesmo modo de falha de `site_corp`, que tem 11 docs — e por isso lá o item é `DOC-01`).
- **Mudança aplicada:** `README.md` agora lista a finalidade/status dos quatro documentos e identifica
  `MELHORIAS.md` + `PLANO-DE-MELHORIAS.md` como fontes operacionais atuais.
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

- **Arquivo:** `SECURITY.md`
- **Evidência inicial:** havia `LICENSE` e README, sem guia de reporte.
- **Impacto:** baixo (jogo estático, sem servidor de lógica), mas o `SEC-01` (supply chain do CDN) é
  um tema que deveria ficar registrado.
- **Mudança aplicada:** `SECURITY.md` registra o escopo estático, o canal de reporte privado e o papel do SRI.
- **Aceite:** arquivo existe.
- **Verificação:** `ls SECURITY.md`

---

## 7. DevOps / Infra

### DEVOPS-01 · Pin da imagem base do nginx · [P2]

- **Arquivo:** `Dockerfile`
- **Evidência inicial:** `FROM nginx:alpine` — tag **sem versão**.
- **Impacto:** (a) **não-reprodutibilidade**: o mesmo `docker build` em datas diferentes traz nginx
  diferente (foi o que trouxe `1.31.5` na versão testada — pode mudar a qualquer momento);
  (b) **supply chain**: `nginx:alpine` é tag móvel; um movimento de tag (ou conta upstream
  comprometida) muda o código que serve o jogo.
- **Mudança aplicada:** imagem pinada em `nginx:1.31.6-alpine3.24`. O pin por tag fixa a versão declarada;
  ainda não fixa o digest imutável.
- **Aceite:** rebuild 30 dias depois usa a mesma imagem base.
- **Verificação:**
  ```bash
  grep '^FROM' Dockerfile                      # deve ter versao ou digest
  docker inspect --format '{{index .RepoDigests 0}}' nginx:alpine   # ver digest
  ```

### DEVOPS-02 · Compose sem `read_only`/limites · [P3]

- **Arquivo:** `docker-compose.yml`
- **Evidência inicial:** só `build`, `ports`, `restart`. Sem `read_only`, `security_opt`, `mem_limit` ou
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

### Ordem original do diagnóstico (rastreabilidade)
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

As mudanças de código dessas ondas foram aplicadas nesta rodada. A sequência abaixo registra as dependências
consideradas. A validação em navegador/container continua pendente.

**Dependências consideradas:**
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
- [x] `SEC-01` — hashes SRI declarados no import map para os módulos CDN usados; aceite de navegador pendente
- [x] `SEC-02` — Nginx configurado para 404 em caminhos inexistentes
- [x] `SEC-03` — CSP e headers de segurança configurados; compatibilidade em navegador pendente
- [x] `SEC-04` — `server_tokens off` configurado; resposta HTTP pendente de verificação
- [x] `SEC-05` — Dockerfile copia apenas os arquivos previstos e remove o `50x.html` herdado

**Funcional**
- [x] `BUG-01` — plano atualizado; CI extrai o módulo embutido para checar sintaxe
- [x] `BUG-02` — `preview.png` removido da imagem Docker
- [x] `BUG-03` — `/LICENSE` configurado como texto e caminhos sem arquivo retornam 404

**Qualidade e operação**
- [x] `IMP-01` — workflow definido com `docker build` + `node --check`; publicação/execução pendente
- [x] `IMP-02` — healthcheck definido no Compose; aceite em container pendente
- [ ] `IMP-03` — (P3) HTML dividido, se decidido

**Documentação e operação**
- [x] `DOC-01` — índice dos documentos na raiz
- [x] `DOC-02` — mudanças consolidadas em `95a1f46`; working tree limpo e sincronizado com `origin/main`
- [x] `DEVOPS-01` — imagem base pinada por versão/tag (digest ainda não fixado)
- [x] `DEVOPS-02` — Compose com `read_only`, capabilities reduzidas e `no-new-privileges`
- [x] `DOC-03` — `SECURITY.md`

**Aceites em runtime pendentes (não executados nesta rodada):**
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

*Fim do diagnóstico-base. Gerado por leitura do código **e execução real** (container construído, subido e
testado por `curl`) em 2026-10-02. Consolida `MELHORIAS-3D-E-IA.md`, `MELHORIAS-LOOPING.md` e
`PLANO-DE-MELHORIAS.md` — que **não** foram repetidos aqui.*
