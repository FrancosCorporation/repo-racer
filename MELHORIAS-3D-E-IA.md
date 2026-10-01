# Repo Racer — verificação completa: 3D, IA de rivais/chefão e cérebro LLM local

> Documento de trabalho da verificação pedida em 30/09/2026: estado dos **carros**,
> **rivais**, **chefão SEGV** e **gráficos 3D**, o diagnóstico do "travando" do
> chefão e a decisão de IA — incluindo o **cérebro LLM local (WebLLM/WebGPU)**,
> reaproveitando o padrão já validado no repositório **`botao_ia`**.
> Cada item do backlog tem número (B1, B2, …) e status: ⬜ pendente ·
> 🔷 em andamento · ✅ implementado e validado.
> **Este é o documento-parâmetro das melhorias de 3D/IA** (o outro doc do repo,
> `MELHORIAS-LOOPING.md`, cobre o looping — já 100% fechado).

---

## 1. Estado do repositório (verificado em 30/09/2026)

| Item | Situação |
| --- | --- |
| Repositório | `FrancosCorporation/repo-racer`, branch `main` limpa e sincronizada (`dd42cdb`) |
| Arquitetura | **Single-file**: o jogo inteiro é o `index.html` (4 362 linhas, ~195 KB); Three.js r160 por CDN/importmap; **sem build**, sem npm |
| Hospedagem | GitHub Pages (online) + Docker/nginx que só serve o estático |
| Docs | `README.md` + `MELHORIAS-LOOPING.md` (looping: diagnóstico, correções e validação) — **não existia** doc de 3D/IA; este passa a existir |
| Identidade a preservar | cidade neon, **13 praças = 13 repos** (foco principal: explorar e abrir no GitHub com `E`), fases com dificuldades, PT-BR, single-file/CDN, diversão em primeiro lugar |

### 1.1 O repositório da IA pequena (base do cérebro)

`FrancosCorporation/botao_ia` (commit `513dc3a` — "modo LLM 100% local — WebLLM/WebGPU
roda no navegador"):

- **WebLLM embutido** (`js/vendor/webllm.esm.js`, 6,07 MB — bundle jsDelivr do
  `@mlc-ai/web-llm@0.2.85`, a mesma versão publicada hoje como `latest`);
- **Qwen2.5-0.5B-Instruct-q4f16_1-MLC** (~350 MB de download único, cache do
  navegador) e **SmolLM2-360M-Instruct** como opção leve; Qwen3-0.6B testado e
  **descartado** (gasta tokens "pensando" e não obedece o JSON);
- **Padrão de integração** (reaproveitado aqui): o LLM **não inventa** a jogada —
  o jogo monta um **menu de candidatos já avaliados** (score) e o modelo só
  **escolhe um**, respondendo `{"i": nº, "motivo": "..."}`; JSON validado contra o
  menu, **2ª tentativa** com limite explícito e **fallback heurístico em qualquer
  falha** — o jogo nunca trava;
- Roda **sem servidor e sem API**: 100% no navegador via **WebGPU**; se não houver
  placa, cai no SwiftShader (CPU). Depois do 1º download, o jogo fica offline.

### 1.2 Ambiente de validação disponível

- Chrome **152** (headless) com WebGPU funcionando: `google/swiftshader` (software)
  e **`amd/rdna-2` (GPU real)** com `--enable-unsafe-webgpu --use-vulkan=native`;
- Node 22 + CDP (DevTools Protocol) para o harness; Python 3.14 para servir o estático;
- Medição dinâmica possível **sem servidor de IA**: o teste roda o jogo + o modelo
  de verdade no navegador headless, exatamente como o jogador veria.

## 2. Verificação — o que está bom e o que está fraco

### 2.1 🚗 Carros do jogador — **fraqueza visual clara**

- Os 3 carros (`CARS`, linhas 309–313) têm **geometria idêntica**: só mudam
  cor, brilho e 3 números de stat (accel/max/grip). NEON, PHANTOM e TANK
  **não têm identidade 3D própria** — o jogador só percebe a diferença dirigindo.
- A base é boa e reutilizável: carroceria `RoundedBoxGeometry` com clearcoat,
  rodas com aro de 5 raios e tampão emissivo, fita de neon nas saias, faróis,
  lanternas, spoiler, para-choque que amassa (dano cosmético), chamas de nitro.

### 2.2 👾 Rivais (fase CAÇADA) — **IA rasa e sem leitura visual**

- `makeEnemyCar` (1830–1854) = carro do trânsito pintado + faixa + halo — sem
  silhueta própria e **com um `PointLight` por rival** (3 a 5 luzes em jogo).
- `updateEnemies` (1886–1998): FSM única `stalk → telegraph → charge → recover`,
  igual para todos; "flanquear" é só um deslocamento em seno no ângulo (1907–1908);
  todos perseguem o mesmo alvo (empilham, sem papéis); **sem separação**;
- Colisão com prédios = *clamp* por eixo + `speed *= 0.3` (1933–1943) — **grudam
  em cantos**; não desviam de rampas, do looping nem do trânsito.
- Leitura de intenção fraca: nada na tela avisa "ele vai carregar" além do beep.

### 2.3 😈 Chefão SEGV — **trava e é previsível**

- `updateBoss` (2735–2845): persegue com antecipação (bom) e tem janela de
  vulnerabilidade (bom), mas:
  - **desvio de prédios = sonda de 3 pontos com raio fixo 4.5** (`bossAvoid`,
    2547–2564) — não cobre rampas/looping; **não é pathfinding**;
  - colisão = *clamp* por eixo + `speed *= 0.25` + auto-dano (2790–2807):
    o SEGV **fica preso/raspando nos quarteirões** (o "travando" relatado);
  - cadência **totalmente fixa** (telegraph 0,9 s → carga 1,7 s → recover 2,2 s);
    **sem feints, sem fase 2, sem reagir** a jogador parado ou em nitro.

### 2.4 🐌 O "travando muito" — três causas prováveis (medir no harness)

1. **Recompilação de shaders em runtime**: a luz de cada rival nasce/morre com a
   horda (`spawnEnemies`/`clearEnemies`) e o beacon do SEGV entra na 1ª luta —
   no three.js, mudar a **quantidade de luzes** recompila os materiais da cena
   → engasgo no início da caçada e da arena;
2. **Colisão por eixo** (2.2/2.3) — o chefão literalmente fica preso na geometria;
3. **Custo de GPU sem qualidade adaptativa dinâmica**: bloom + SMAA + sombra 2048
   + centenas de draw calls; com `MAX_STEPS = 5` (1/60 fixo) um quadro longo
   desacelera a simulação (sensação de lag). Há ainda alocações por frame
   (`new THREE.Vector3` no `present`, `'♥'.repeat` no HUD do boss a cada quadro).

### 2.5 🎨 Gráficos — base rica, sem "leitura de jogo"

- Já existe: bloom (0.72/0.55/0.78), vinheta+aberração cromática+saturação
  (GradeShader), SMAA no desktop, tone mapping ACES, PMREM de cidade neon,
  névoa, céu + 1 300 estrelas + lua com halo, prédios com janelas que respiram,
  coroas neon, antenas piscando, postes, poças refletivas, instancing dos
  prédios da orla (2 draw calls), minimapa, fantasma do looping, faíscas,
  fumaça, marcas de pneu.
- **O que falta é comunicação visual de gameplay**: silhuetas distintas (carros
  e rivais), telegrafo visível no inimigo, estados do chefão (fase/carga/recuo)
  e feedback de freio/setas no trânsito. É por aí que as melhorias entram —
  sempre com custo ~0 (geometrias/materiais reusados, sem novas luzes por frame).

## 3. Decisão de IA — cérebro LLM local (WebLLM) como camada opcional

### 3.1 Modelos avaliados (e por quê)

| Modelo | Formato/Runtime | Veredito |
| --- | --- | --- |
| **SmolLM2-360M-Instruct** (`HuggingFaceTB/SmolLM2-360M-Instruct`) | MLC **pré-compilado p/ WebLLM** (`mlc-ai/SmolLM2-360M-Instruct-q4f16_1-MLC`) e ONNX | ✅ **escolhido para o teste** — menor modelo utilizável no stack do jogo |
| Qwen2.5-0.5B-Instruct | MLC pré-compilado (validado no `botao_ia`, JSON perfeito) | ⭐ plano B imediato (seletor já o inclui) |
| SmolLM2-135M-Instruct | MLC existe + ONNX | 🧪 mínimo absoluto — abaixo da linha de confiabilidade p/ JSON |
| Qwen3-0.6B | MLC | ❌ descartado no `botao_ia` (tokens "pensando", não obedece JSON) |
| gemma-3-270m-it | sem MLC (só ONNX community) | ⚠️ rota transformers.js, não provada no stack |
| `RKNNAI/RK182X-LLM-Qwen3-0.6B` | **RKNN** (NPU Rockchip RK182X) | ❌ hardware NPU físico; não roda no navegador |
| `nvidia/Nemotron-3-Diarization` | NeMo/GGUF (áudio) | ❌ é diarização de fala (quem falou quando), não LLM de decisão |

### 3.2 Arquitetura do cérebro no jogo (padrão `botao_ia` adaptado)

1. **Menu de táticas com score local** — a FSM de rivais/SEGV gera 4 táticas
   (ex.: CARGA DIRETA, FINTA, CORTAR CAMINHO, RECUO TÁTICO) com descrição e
   score heurístico do estado atual (distância, alinhamento, velocidade, vida);
2. **O LLM só escolhe 1** — prompt curto pt-BR, `temperature 0`, resposta
   `{"i": nº, "motivo": "..."}`; índice validado contra o menu;
3. **2ª tentativa** com limite explícito se o JSON vier torto; **fallback
   heurístico** (argmax do score) em qualquer falha/timeout — o jogo nunca trava;
4. **Decisão assíncrona com cadência**: 1 requisição em voo, só nas transições
   de modo (a FSM segue valendo enquanto o modelo "pensa"); raiz dos rivais:
   apenas o líder pede; cooldown global;
5. **Zero servidor/API**: WebLLM via CDN pinado (v0.2.85) + pesos baixados **uma
   vez** do Hugging Face e cacheados pelo navegador; depois disso, offline;
6. **Opcional e visível**: botão no menu (`CLÁSSICO → LLM 360M → LLM 0.5B`),
   linha de status no HUD (`CÉREBRO 360M · 7/9`), e o "motivo" do modelo aparece
   em toast — a IA local explicando a própria jogada (ótimo para demonstração).

## 4. Plano completo (backlog numerado)

| # | Fase | Itens | Status |
| --- | --- | --- | --- |
| A | **Doc-parâmetro** (`MELHORIAS-3D-E-IA.md`) | verificação + plano + resultados | ✅ |
| B | **Perf: acabar com as travadas** | B1 pool fixo de luzes (sem recompilar shader) ✅ · B2 colisão deslizante + unstick ✅ · B3 qualidade adaptativa dinâmica ✅ · B4 zero alocação por frame ✅ | ✅ |
| C | **IA clássica** | C1 pathfinding na grade de ruas (waypoints) ✅ · C2 rivais com papéis/pinça/separação ✅ · C3 SEGV fase furiosa + punição de camper ✅ | ✅ |
| D | **Cérebro LLM local** | D1 módulo WebLLM + menu/seleção · D2 integração rivais/SEGV · D3 fallback/retry/cadência · D4 testes | ✅ |
| E | **3D visual** | E1 kits próprios por carro ✅ · E2 rivais legíveis ("!", giroflex, dentes) ✅ · E3 SEGV com rastro/fumaça/fase ✅ · E4 trânsito com freio real ✅ · E5 detalhes de rua (manhole/faixa) | ⬜ |
| F | **Validação + docs + commits** | harness CDP, README, doc com resultados, commits temáticos | ✅ |

> Ordem de execução acordada: **D (testar o 360M primeiro)** → depois B/C/E com o
> mesmo rigor. **D, B, C e E1–E4 estão fechados** (seções 6 e 8); **E5** (detalhes
> de rua: tampas de esgoto/faixas) ficou em aberto por ora — é puramente
> cosmético e o resto já mudou a experiência.

## 5. Implementação do cérebro (D1–D4) — o que entrou no jogo ✅

- **UI no menu**: botão `CÉREBRO DOS INIMIGOS` que cicla
  `CLÁSSICO → LLM 360M → LLM 0.5B → CLÁSSICO`, com linha de status embaixo
  (progresso do download, modelo ativo e contagem `decisões no LLM: ok/total`);
  quando ativo, aparece a linha `CÉREBRO 360M · 7/9` no HUD.
- **Módulo no `index.html`** (bloco `CÉREBRO LLM LOCAL`): WebLLM **0.2.85 via CDN
  pinado** (`esm.run/@mlc-ai/web-llm@0.2.85`), `CreateMLCEngine` com callback de
  progresso; extração de JSON balanceado; validação contra o menu; **2ª tentativa**
  com limite explícito; **fallback heurístico**; `temperature 0`, `max_tokens 60`.
- **Integração no gameplay**:
  - **SEGV** decide na transição `stalk → telegraph` com 4 táticas: `CARGA DIRETA`,
    `FINTA` (telegrafa curto, recua 0,75 s e volta cobrando), `CORTAR CAMINHO`
    (mira o ponto de interceptação por 1,4 s a +12% de velocidade) e `RECUO TÁTICO`;
  - **rivais**: só o **líder da matilha** pergunta (1 pedido por vez no jogo todo);
    táticas `CARGA AGORA`, `FLANQUEAR ESQUERDA`, `FLANQUEAR DIREITA` e `SEGURAR`
    (reduz a velocidade da matilha por 1,6 s);
  - cadência: **1 requisição em voo**, cooldown de 2,5 s (SEGV) e 4 s (rivais);
    enquanto o modelo "pensa", a FSM clássica segue valendo (o SEGV hesita de
    propósito) — nada bloqueia o frame.
- **Garantias de projeto**: **sem servidor e sem API** (só a lib via CDN + o
  download **único** dos pesos no HF, cacheados pelo navegador; depois disso roda
  offline); sem WebGPU o botão avisa e o jogo segue no clássico; nada disso muda o
  `docker`/GitHub Pages (continua tudo estático).

## 6. Teste do SmolLM2-360M — resultados medidos (30/09/2026) ✅

**Ambiente**: Chrome 152 headless com WebGPU na **GPU real (`amd/rdna-2`)** via
Vulkan/ANGLE; harness CDP em Node 22; servidor estático Python em `8099`.

| Teste | Resultado |
| --- | --- |
| Carga do modelo (1ª vez) | **16,1 s** (download q4f16 + compilação); fica no cache do navegador |
| Bateria de 6 decisões canônicas | **6/6 JSON válido**, `i` sempre dentro do menu; **0,55–2,85 s** por decisão |
| Robustez (motor falso) | lixo → 2 tentativas → rejeitado; `{"i": 99}` (fora do menu) → rejeitado; ```` ```json ```` válido → aceito |
| Caçada ao vivo | decisões aplicadas (toast `RIVAL (IA): ACELERA`); modos evoluíram (stalk/telegraph/charge/recover) |
| Boss ao vivo | decisão aplicada (toast `SEGV (IA): quase parado`); SEGV passou pelos 4 modos; console limpo |
| Fallback ao vivo (motor que sempre falha) | `reqs 1 · ok 0 · fallback 1` — o SEGV **continuou lutando** nos 4 modos clássicos, sem erros |

**Veredito: o SmolLM2-360M dá conta da tarefa.** Em todas as medições ele escolheu
uma tática **válida** do menu (JSON correto, índice dentro da lista) e a decisão
chegou ao jogo. O ponto fraco é o **texto** do motivo: às vezes sai truncado ou
embaralhado com o prompt (ex.: `"Ao que o jogador vai estar no tempo de recuar…"`),
embora também saiam motivos perfeitos (`"ACELERA"`, `"acelera e tenta o bote neste
rival"`). Como o motivo é **cosmético** (a jogada vem do menu validado), isso não
quebra a experiência — e o **Qwen2.5-0.5B** já está no seletor como upgrade para
quem quiser motivos melhores e mais variedade (a troca é 1 clique).

## 7. Roteiro de validação (como repetir)

- Harness em `/tmp/rrllm` (fora do repo): `probe.mjs`/`matrix.mjs` (WebGPU no
  headless), `game-check.mjs` (regressão sem LLM), `llm-test.mjs` (carga, bateria,
  robustez e jogo ao vivo), `live-test.mjs` (decisões ao vivo intercaladas) e
  `fallback-live.mjs` (fallback com motor falso).
- Manual (jogador): `python3 -m http.server 8080` → abrir `index.html?debug=1` →
  clicar no botão **CÉREBRO** → console: `__rr.llm.status()`, `__rr.llm.test(6)`.
- Limitações conhecidas: SwiftShader/CPU não foi medido (esperado: mais lento que
  os 0,55–2,85 s da GPU); o motivo do 360M é imperfeito; ele tende a repetir a
  opção de maior score (comportamento seguro, mas pouco "criativo").

## 8. Resultados das fases B/C/E — validado em harness (30/09/2026) ✅

Harness `bce-check.mjs`/`bce-fix.mjs` (Chrome headless, GPU `amd/rdna-2`, janela
ao vivo intercalada) + re-execução do teste do cérebro sobre o código novo:

| Verificação | Resultado |
| --- | --- |
| B1 — contagem de luzes (base × caçada × arena) | **7 = 7 = 7 = 7** — nada muda luz em runtime, zero recompilação de shader |
| B2 — atolamento do SEGV (26 amostras com velocidade > 5) | **0** (antes: clamp por eixo travava no canto) + "SEGV MANOBRA!" de resgate |
| B2 — grade de ruas (C1) | waypoints do SEGV preenchidos durante a luta (`teveWaypoints: true`) |
| B3 — qualidade adaptativa forçada | nível 0→2: SMAA desligado, bloom 0,72→0,5, pixel ratio reduzível |
| B4 — frame a frame (GPU real) | **avg 16,8 ms · p95 20,9 ms** (60 fps travado), console limpo |
| C2 — papéis + separação | `role0 = "bloqueador"`; modos da matilha evoluindo nos 4 estados, sem empilhar |
| C3 — fase furiosa | dano até **40% da vida** → `furioso: true` (olho/faixa âmbar, telegrafa −28%) |
| C3 — punição de camper | jogador parado >2,5 s → próxima investida em 0,5 s (lógica no `stalk`) |
| E1 — kits 3D por carro | NEON `[t,f,f]` · PHANTOM `[f,t,f]` · TANK `[f,f,t]` |
| E2 — leitura de intenção | sprite **"!"** visível no telegrafo (`alertViu: true`), giroflex presente, `role0` correto |
| E3 — SEGV com presença | rastro de faíscas na carga e fumaça <35% de vida, exercitados sem exceção |
| E4 — freio do trânsito | na frente: **12,7 → 7,9** u/s com lanterna forte; livre: volta a **12,7** |
| Regressão geral | fase + arena via `__rr.step()` **sem exceções; 0 erros de console** |
| Cérebro LLM sobre o código novo | carga **5,1 s (cache do navegador)** · bateria **6/6 JSON** · caçada `ok 2/2` · boss `ok 3/3` · toasts aplicados |

**Veredito: B, C e E1–E4 fechados.** O "travando" do chefão atacado nas três
frentes (luzes constantes, colisão deslizante + unstick e qualidade adaptativa) e
a jogabilidade ganhou a grade de ruas, papéis na matilha, fase furiosa e leitura
visual. Pendência cosmética única: **E5** (tampas de esgoto/faixas na rua).





## 9. Rodada de feedback — laço, GPS, fachada e carro (30/09/2026) ✅

Cada sintoma foi diagnosticado por screenshot + telemetria (harness CDP em Node
com Chrome headless) antes de mexer no código — nenhuma correção por adivinhação.

| Sintoma relatado | Causa real (achada no screenshot/objeto) | Correção |
| --- | --- | --- |
| "seta grande com uma sombra/funil bege à frente" | o **cone do farol**: `ConeGeometry(2.2, 15, 20)` a 9,6 m, opacidade 0,07, aditivo — uma tenda creme de 15×4,4 m | cone 1,25×8 m, opacidade **0,028**, colado no chão (0,55 m) |
| "GPS: uma setinha grande e outra pequenininha" | `wayArrowMesh` com escala 0,92, 7 m à frente e anel de 1,6 m | escala **0,6**, 7 m à frente, 2,45 m de altura, anel menor e mais apagado |
| "linhas pretas em volta do looping" | textura do tubo era `#141c2c` com **40 travessas pretas** e `DoubleSide` — via-se por fora | asfalto `#2a3650→#1b2436` com faixa central tracejada e linhas de borda, `repeat 6`, **`BackSide`** + casca externa |
| "dentro do looping não tem parede nenhuma" | o tubo era só a textura; nada marcava as arestas por dentro | **casca sólida** (R+0,45, largura +0,6), **guard-rails** nas duas arestas, **fitas de neon** rente a elas, emissive 0,3→0,45 |
| "a entrada do looping fica escondida" | cartaz de repo de **14 m** dentro do tubo: pad #1 em (40,40), a 5,6 m do centro; e pad #3 (40,-40) no corredor | pad #1 → (80,120) + **regra automática** que empurra qualquer pad alinhado com o corredor do laço; banner da fase `p6` sobe (13,5 m) e encolhe (9 m) |
| "prédios com parede lisa" | textura 128×256 com janelas esparsas sobre fundo **100% preto** | 128×512 com faixa de andar, pilastras, grade 2× mais densa (janela acesa **e apagada**) e térreo com vitrine; **PRNG local** para não consumir o `rand()` global (layout da cidade idêntico) |
| "o carro parece simples demais" | faltava o que a câmera de corrida realmente vê | faixa central no capô/teto/traseira, barra de freio de largura total, difusor com aletas, escapes e retrovisores |

### Verificação (harness, 30/09/2026)

| Teste | Resultado |
| --- | --- |
| Volta completa (`fb4.mjs`) | boca `a=-0,5` → lateral `y=4,5` → **topo `y=19,3`** → descida → **saída `laps=1`** |
| Matriz de entrada (`entrada.mjs`) em 14/20/28/40 u/s | **4/4 completam a volta**, `travouFrames: 0` em todas |
| Card no laço | **0 sprites** a menos de 18 m do centro do tubo (antes: 1 de 14 m em cima da pista) |
| Erros de console | **0** em `vis.mjs`, `game-check.mjs` e `bce-check.mjs` |
| Regressão de performance | luzes 7 = 7 = 7, frame **avg 16,6 ms · p95 19,5 ms**, SMAA/bloom intactos |

**Veredito:** laço, GPS e a leitura visual do carro/prédio estão fechados com
evidência. Pendências cosméticas que sobraram: **E5** (tampas de esgoto/faixas na
rua) e o teste do **Qwen2.5-0.5B em navegador real**.
