# Looping & rampa — verificação completa, correções e melhorias

> Documento de trabalho da verificação do **looping estilo Hot Wheels** (e do
> entorno) do Repo Racer. Reúne o diagnóstico com evidências medidas, as
> correções aplicadas no `index.html`/`README.md` e o roteiro de validação.
> Tudo o que está marcado como ✅ foi implementado neste commit; o que ficou
> fora está no backlog (seção 6).

---

## 1. Estado do repositório (o projeto está comitado?)

**Sim — tudo comitado e sincronizado.** Na data da verificação:

```
$ git status --short --branch
## main...origin/main          # sem divergência e sem alterações pendentes

$ git log -1 --stat
91b196b feat: cidade mais viva — crosswalks nas esquinas, calçadas e antenas piscando
 README.md  |  9 +++++---
 index.html | 85 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
```

- Working tree limpo: nenhum arquivo modificado/untracked.
- Último commit (`91b196b`) = o do "crosswalks/calçadas/antenas", já em `origin/main`.
- Sem `TODO`/`FIXME` no código; o projeto continua *single-file* (`index.html`),
  Three.js r160 por CDN, sem build.

---

## 2. Como a verificação foi feita

| Etapa | Ferramenta | O que produziu |
| --- | --- | --- |
| Leitura estática | `grep`/leitura do `index.html` (3 928 linhas) | mapa do laço: construção, `loopGround`, gatilho, passeio, saída |
| Teste **dinâmico** | `python3 -m http.server` + **Chrome 152 headless** (SwiftShader) + harness CDP em Node 22 | telemetria frame a frame (`window.__rr`), captura de `console`/exceções |
| Visual | `Page.captureScreenshot` via CDP (1000×600) | 3 screenshots do deck, da boca e da saída |

Harness usado (arquivos temporários em `/tmp`, não fazem parte do repo):
`/tmp/rr-test*.mjs` — conecta no DevTools Protocol, abre
`http://127.0.0.1:8099/index.html?debug=1`, chama `__rr.setCar(...)` e anda o
jogo com `__rr.step(1)`, registrando posição/velocidade/`loopA` **a cada frame**.

> A física do jogo usa timestep fixo (`FIXED_DT = 1/60`, até 5 steps por quadro),
> então `step(1)` reproduz exatamente o que um jogador veria a 60 fps.

---

## 3. Diagnóstico — o que estava quebrado

Notas: `needV` = velocidade mínima do gatilho = `sqrt(2·26·2R)·0.98` = **33,14 u/s**
(≈ 133 km/h na HUD, que multiplica por 4). Carros: NEON `max 34`,
PHANTOM `max 40`, TANK `max 29`. Centro do laço em `(36, 36)`, `R = 11`,
largura `W = 9`; bocas do tubo em `|dz| = 5,5` (y = 1,474 — altura idêntica à do
deck, `deckH(±5,5) = 1,47`).

### B1 — Teleporte na ENTRADA do laço (crítico) ✅

- **Sintoma:** ao cruzar a boca sul, o carro "pula" para dentro do tubo.
- **Medido:** frame 45→46, carro em `(36, 30.50, 1.470)` → `(36, 36.57, 0.015)`:
  **Δz = +6,07 e Δy = −1,46 em um único frame (16,7 ms)**.
- **Causa:** o gatilho marcava `state.loopA = 0`, mas o passeio é
  `z = LOOP.z + sen(a)·R`, `y = R − cos(a)·R` — ou seja, `a = 0` é o **ponto mais
  baixo** (`z = LOOP.z`, `y = 0`), ~6 u à frente da boca. A boca sul corresponde a
  `a = −asen(5,5/11) = −π/6`.
- **Correção:** o passeio passou a começar na **boca sul** usando o ângulo da
  posição real do carro (`asin((z − LOOP.z)/R)`), sem salto.

### B2 — Teleporte na SAÍDA do laço (crítico) ✅

- **Sintoma:** fim da volta, o carro reaparece na rampa de saída atravessando o piso.
- **Medido:** frame 165→166, `(36, 35.45, 0.014)` → `(36, 41.80, 1.442)`:
  **Δz = +6,35 e Δy = +1,43 em um frame**.
- **Causa:** a condição de fim era `loopA >= 2π` (ponto mais baixo) e o código
  então "teleportava" o carro para `z = LOOP.z + 5,8`.
- **Correção:** a volta termina na **boca norte** (`LOOP_A_EXIT = 2π + asen(5,5/R)`),
  posição contínua com a rampa: `z = LOOP.z + 5,5`, `y = deckH(−5,5) = 1,47`.

### B3 — "Snap" lateral de até 4,5 u na entrada (alto) ✅

- **Medido:** entrando deslocado em `x = 33,5`, o frame do gatilho trouxe
  **Δx = +2,5** (junto com Δz = +6,37 e Δy = −1,43) — o passeio forçava `x = LOOP.x`.
- **Correção:** o passeio guarda `state.loopX` e converge para o eixo do tubo
  (`dt·2,5`), sem teleporte.

### B4 — Boost pads não funcionam / TANK nunca completa o laço (alto) ✅

- **Sintoma:** o TANK (máx 29) bate na boca mesmo passando pelos dois pads.
- **Medido (headless, TANK selecionado na garagem):** os pads disparam
  (`vel = 38,1` em `z = 15,1` e `20,9`), mas a velocidade volta a **29** e o
  carro **bate na boca** (`entrou no laço? false`, velocidade ficou negativa).
  Com nitro (`vel = 42,05`) ele entra.
- **Causa:** ordem no `update` — o clamp (`clamp(state.speed, MAX_REVERSE,
  maxSpeed)`, com `maxSpeed = stats.max`) roda **antes** do trecho do laço; o
  `+26` do pad era descartado no frame seguinte. Para o NEON/PHANTOM isso é
  invisível (eles já passam de 33,14), então **os pads eram decorativos**.
- **Correção:** o pad agora liga `state.padBoost = 1,2` e o clamp do frame
  seguinte respeita `stats.max · 1,45` enquanto o boost durar → o TANK chega à
  boca a 38,1 e completa o laço.

### B5 — O tubo não é sólido de lado (médio) ✅

- **Sintoma:** entrar na "tigela" pela lateral do tubo não bate: o carro sobe.
- **Medido:** a 30 u/s em `z = 41` (|dz| = 5) rumo ao leste, o carro **pula
  Δy = +1,202 em um frame** (vy travado em 10), anda por cima da casca e cai do
  outro lado — contradiz o "ninguém atravessa a estrutura".
- **Causa:** o bloqueio de degrau (`blocked`) só existia para as rampas
  (`RAMP_DEFS`); o tubo só tinha a função de altura.
- **Correção:** cruzar a lateral do tubo (eixo X) com a casca acima de 25 cm
  vira **parede**: posição revertida, faísca, tremor e perda de velocidade. O
  "piso do corredor" central (|dz| ≲ 2,3 — onde o tubo encosta no chão)
  continua passável, como antes.

### B6 — `ReferenceError: smaa is not defined` a cada resize (médio) ✅

- **Evidência (console do Chrome headless, durante o teste):**
  `Uncaught ReferenceError: smaa is not defined at index.html:3846`.
- **Causa:** o passe SMAA foi removido no commit `49c927b`, mas a linha
  `if (smaa) smaa.setSize(...)` ficou no handler de `resize` — a variável não
  existe em nenhum outro ponto do arquivo (confirmado por `grep`).
- **Correção:** o passe **SMAAPass voltou** de verdade (`three/addons/postprocessing/SMAAPass.js`),
  atrás de `!LOW_END` + `try/catch`, e a linha do resize passou a ser válida
  (o composer já redimensiona os passes; agora o AA existe mesmo).

### B7 — Letreiro "ENTRADA" espelhado (médio) ✅

- **Evidência:** screenshot do carro chegando do sul mostra o texto invertido
  (lê-se "ADARTNE"): o `PlaneGeometry` nasce virado para +Z (norte), então quem
  chega pelo sul vê o **verso** (textura espelhada por causa do `DoubleSide`).
- **Correção:** a placa de entrada recebeu `rotation.y = π` e agora informa a
  velocidade mínima na própria placa ("MIN 133 KM/H").

### B8 — Inclinação do chassi dava "cotovelada" de ~25–35° (médio) ✅

- **Causa:** a tangente do tubo na boca é de 30°, mas o deck tem 5,4°; a troca
  acontecia em um único frame (`carBody.rotation.x = -loopA`).
- **Correção:** `bodyPitch()` faz um blend de ~0,2 s (`loopPitchFrom` +
  `loopPitchBlend`), ancorado no ângulo que o carro já tinha na tela — vale para
  a entrada **e** para a saída.

### B9 — Diversos (baixos) ✅

| # | Item | Evidência/Causa | Correção |
| --- | --- | --- | --- |
| B9.1 | Toast sempre "LOOPING 1x" | `loopLaps = 0` no gatilho + `++` na volta → nunca passava de 1 | toast agora mostra a **volta em segundos** |
| B9.2 | Orbes do laço nunca renasciam | `taken` ficava `true` para sempre (N2O renasce em 40 s) | respawn de **40 s** por orbe |
| B9.3 | Z-fighting no fundo do tubo | a casca toca `y = 0` exatamente e o chão também (`PlaneGeometry(600,600)` em y = 0) | `polygonOffset` no material do tubo |
| B9.4 | `state.looping` não era limpo em `startPhase`/`startBoss`/`setCar` (debug) | o passeio "gruda" o carro; atrapalhava testes | limpeza dos campos do laço nesses pontos |
| B9.5 | Muros do cenário cortavam a rua sul | `wall` centrado em `z = LOOP.z − 30` com 26 de comprimento → ia de z = −7 a 19 (a rua vai de −6 a 6) | centrado em `z = LOOP.z − 17` (z = 6..32) |
| B9.6 | Lixeiras dentro da rua | `tz = LOOP.z − 34,5` ≈ z 1,5–2,8 (pista) | movidas para z ≈ 11–12,3 |
| B9.7 | Faixa de pedestre invadindo a calçada | barras centradas em z = 3,5 (metade fora da pista, dentro da calçada) | centrada na rua (z = `LOOP.z − 36`), barras de 11,5 |
| B9.8 | Melhor volta invisível na HUD | `LOOP_BEST_KEY` só alimentava um toast | linha **MELHOR VOLTA** no painel `#stats` |
| B9.9 | Looping fora do minimapa | só `RAMP_DEFS` era desenhado | anel laranja no minimapa |
| B9.10 | Sem feedback de velocidade na boca | bater devolvia só `onCrash()` | portal sul vira **semáforo** (verde = dá, vermelho = falta) + toast "MUITO LENTO" com cooldown |

---

## 4. Arquivos alterados

- `index.html` — física/visual do laço, HUD, minimapa, SMAA, cenário.
- `README.md` — números reais do laço (133 km/h, pads com boost temporário,
  TANK precisa de pads/nitro), orbes com respawn, melhor volta na HUD.
- `MELHORIAS-LOOPING.md` — este documento.

## 5. Validação (roteiro usado, repetível)

```bash
# 1) servir o jogo e abrir com debug (o harness usa window.__rr)
python3 -m http.server 8099 --directory .
google-chrome --headless=new --no-sandbox --use-angle=swiftshader \
  --enable-unsafe-swiftshader --window-size=320,180 \
  --remote-debugging-port=9333 'http://127.0.0.1:8099/index.html?debug=1'
node /tmp/rr-test3.mjs   # telemetria por frame (entrada, passeio, saída)
```

Critérios (medidos por frame, com `__rr.step(1)`):

| Cenário | Antes | Depois (medido) |
| --- | --- | --- |
| Entrada a 34 u/s | Δz 6,07 / Δy −1,46 | Δz 1,28 no quadro do gatilho / Δy −0,43 (queda natural da crista da boca) |
| Entrada deslocada (x = 33,5) | Δx 2,5 | Δx 0,104 (converge suave p/ o centro, `dt·2,5`) |
| Saída da volta | Δz 6,35 / Δy +1,43 | Δz 0,34 / Δy +0,18 (sai exatamente na boca norte, z = 41,5) |
| Lateral no tubo (z = 41) | Δy +1,202 subindo a casca | Δy 0 — x trava em 31,50 (parede lateral), nenhuma subida |
| TANK (máx 29) com pads | bate na boca | entra a 39,8 u/s (padBoost 1,2 s) e **completa a volta** (141 quadros, 8/8 orbes) |
| `resize` da janela | `ReferenceError: smaa` | 0 exceções em toda a sessão (inclui 2 resizes forçados) |
| Placa ENTRADA | espelhada | legível em 2 linhas: "ENTRADA / MIN 133 KM/H" |
| Chegada lenta (19,3 u/s) | sem feedback | rebate com −4,9 u/s + toast "MUITO LENTO — O LACO PEDE 133 KM/H" (com cooldown) |
| Semáforo (portal sul) | inexistente | verde `#39ff88` a 34 u/s · vermelho `#ff2d3f` a 20 u/s |
| Toast de volta | só "+800" | "LOOPING! +800 · volta em 0,02s" (o tempo da volta entrou no toast; ~1,8–2,1 s jogando a 60 fps — o 0,02 s é artefato do passo rápido do headless) |
| HUD melhor volta | só dentro do toast | linha **MELHOR VOLTA** exibindo `0,03 s` (gravado em `localStorage`) |

### 5.1 Resultado da validação pós-correção

Rodada em 2026-09-29 com o roteiro da seção 5 (Chrome headless + SwiftShader,
`?debug=1`, harness CDP em Node — arquivos em `/tmp/rr-val*.mjs`, fora do repo).
Saída resumida:

```text
A) ENTRADA CENTRADA 34 u/s  (entrou: true | saiu: true)
   max por frame -> dx: 0 | dz: 1.278 @f41 (gatilho) | dy: 0.762 @f73 (subida do laço)
   gatilho: [36, 30.121, 1.434 -> 36, 31.399, 1.009]  a=-0.432   (antes: salto de 6.07)
   fim     : [36, 41.161, 1.286 -> 36, 41.500, 1.470] loop=0     (antes: salto de 6.35)
   orbes: 8/8 | HUD melhor volta: 0.03s
B) ENTRADA DESLOCADA (x=33.5): max dx: 0.104 | dz: 1.072 | dy: 0.566 | entrou: true
C) LATERAL NA TIGELA (z=41 p/ leste): max dy: 0 | max dz: 0 | x final: 31.497 (bloqueado)
D) CHEGADA LENTA (19.3 u/s nos pads): bateu: true | entrou: false
   toast: "MUITO LENTO — O LACO PEDE 133 KM/H (USE OS PADS OU O NITRO)" | speed: -4.9
E) TANK + pads: entered: true | rode: true | 141 quadros | padMax: 39.8 | orbes 8/8
   série: 29 -> 38.5 (pad) -> 39.8 na boca -> entra e completa
F) semáforo: 34 u/s -> #39ff88 (verde) | 20 u/s -> #ff2d3f (vermelho)
G) resize x2: ERROS/EXCECOES: nenhum
H) screenshot: placa "ENTRADA / MIN 133 KM/H" legível, HUD "MELHOR VOLTA 0.03s"
```

Conclusão: todos os bugs B1–B9 fechados, sem regressões de sintaxe
(`node --check` no módulo extraído) e sem exceções de runtime na sessão completa.
Único artefato remanescente aceito: o quadro do gatilho avança ~0,6 u além do
passo normal (a posição é integrada e depois reparametrizada no arco) — é um
quadro de 16 ms, invisível, e 5× menor que o salto original; a correção exata
(exigiria dividir o quadro na linha da boca) ficou no backlog.

## 6. Backlog — implementado nos commits `de60ef0` + `408b068` ✅

Todos os 6 itens abaixo saíram do papel. Resumo do que foi feito (detalhes no
`git show` de cada commit):

1. **Entrada tangente de verdade** ✅ — o deck agora termina numa curva de
   blend amostrada de `deckH(dz)` (mesma curva na física e no MESH do deck):
   sem voo na chegada, gatilho de cruzamento da boca (posição prévia → atual),
   ângulo inicial a partir do `preZ`. Salto de entrada caiu para
   `dz 0,58 / dy −0,26` (indistinguível de um quadro normal).
2. **Passeio com energia real** ✅ — dentro do laço a velocidade obedece
   `v² −= 2·g·dy` (gravidade segura na subida, empurra na descida); sem fricção
   de rua; sprint final assistido no último quarto. Volta do TANK ≈ 2,02 s.
3. **Câmera dedicada do laço** ✅ — `camera.up` acompanha a tangente
   (`(0, cos a, −sin a)`, eased em y/z sem estalo) + FOV +10 durante o passeio.
   Inversão "de cabeça pra baixo" aparece na tela, não só no chassi.
4. **Ghost/recorde visual** ✅ — `ensureLoopGhost()`: clone translúcido do
   carro refaz o caminho gravado da melhor volta da sessão (playback indexado
   pelo relógio de simulação); placar de voltas por sessão na HUD.
5. **Volta encadeada** ✅ — re-entrar < 45 s após a saída mantém o boost
   (`CORRENTE xN — BOOST MANTIDO!`) e soma pontos extras
   (`800 + 300` por volta na corrente, até `+1200`).
6. **Fase LAÇO INFINITO (`p6`)** ✅ — desafio de fase dentro do laço: cada orbe
   conta 1 de progresso (`type: 'loop'`, overlay dedicado, meta por
   dificuldade).

### 6.1 Correção do cronômetro (`408b068`)

O passeio media a volta com `performance.now()` (tempo de parede). Num harness
que roda N passos de `1/60 s` num só `evaluate`, a parede é milissegundos e o
recorde gravava `0,01 s` falso no `localStorage`. Agora o relógio é `loopTSim`
(tempo de **simulação**, acumulado com `dt` dentro do passeio); o ghost usa o
mesmo relógio. `performance.now` segue usado só para a janela de 45 s da
corrente (tempo real entre voltas). Volta do TANK validada: **2,02 s**
(120 frames), HUD + toast `NOVO RECORDE DE VOLTA! 2,02s` imediatos.

### 6.2 Dívidas conhecidas — RESOLVIDAS ✅

As três dívidas da rodada anterior foram todas fechadas (validadas em
Chrome headless + SwiftShader, harness CDP em Node):

- **Ghost persistente** ✅ — o caminho do recorde agora vai junto com o tempo
  no `localStorage` (`LOOP_GHOST_KEY`, quantizado ~1 amostra/3 frames, volta
  de ~2 s ≈ 1 KB). Na abertura, `loadLoopGhost()` restaura o fantasma se o
  caminho bater com o tempo salvo; `startGame()` não zera mais o
  `loopGhostBest`. Validado: volta → reload real → `ghost:true`, HUD `2,03s`,
  41 amostras restauradas.
- **Snap de câmera no `setCar`** ✅ — o teleporte do harness posiciona a
  câmera atrás do carro e olha pra ele na hora; screenshot imediata não pega
  mais frame transitório. Só roda via `__rr.setCar` (no jogo real não há
  teleporte).
- **TANK** ✅ — turbo extra só dele (`+8·dt`, teto `LOOP_NEED_V·1,1`) fecha a
  conta do pad sem catapultar os outros carros; `crossV` agora é lido DEPOIS
  do turbo (antes o TANK rebatia na boca no mesmo quadro em que ganhava
  velocidade suficiente). Validado: entra pelos pads e fecha a volta
  (`lapT ≈ 2,15 s`). Sem pad/nitro ele continua rebatendo — por design, com
  toast explicando os 133 km/h.
- **Harness**: `__rr.selCar(i)` troca de carro sem passar pela garagem
  (aplica stats + pintura).
