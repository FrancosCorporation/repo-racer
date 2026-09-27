# Repo Racer

## 🐳 Instalação e Execução (Docker) — recomendado

### Pré-requisitos
- [Docker](https://docs.docker.com/get-docker/) + Docker Compose

### Rodar com Docker
```bash
docker compose up --build
```
Para servir via container:
```bash
docker run --rm -p 8080:80 -v $(pwd):/usr/share/nginx/html:ro nginx:alpine
```

### Sem Docker (local)
```bash
# abre o index.html no navegador
open index.html
```

Jogo 3D no navegador em que você dirige por uma cidade neon e **explora os
repositórios** da FrancosCorporation: cada praça iluminada é um projeto — pare
em cima, veja a descrição e pressione **E** para abrir no GitHub.

[![Jogar](https://img.shields.io/badge/JOGAR-agora-39ff88?style=for-the-badge&logo=github&logoColor=white)](https://francoscorporation.github.io/repo-racer/)
![Three.js](https://img.shields.io/badge/Three.js-r160-000000?style=flat-square&logo=threedotjs)
![WebGL](https://img.shields.io/badge/WebGL-3D-990000?style=flat-square)
![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-online-222?style=flat-square&logo=githubpages)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

![Preview](preview.png)

## Recursos

- **Cidade neon 3D** com prédios de janelas iluminadas, postes, estrelas,
  névoa e **bloom** (pós-processamento) com tone mapping cinematográfico
- **Garagem com 3 carros** — NEON (equilibrado), PHANTOM (veloz, traseira
  solta) e TANK (firme) — cada um com cor e dirigibilidade próprias
- **Nitro (Shift)** com barra de recarga, chamas no escapamento e FOV dinâmico
- **Freio de mão (Espaço)** que derrapa de verdade: segure perto da curva para
  escorregar a traseira com fumaça e marcas de pneu
- **Pontuação de drift com combo até x8** — a cadeia de derrapagem acumula
  pontos ao vivo; bater no muro ou no trânsito perde a cadeia ("COMBO
  PERDIDO!") e o recorde de pontos fica salvo no navegador
- **Coletáveis de N2O** espalhados pelas avenidas: reenchem o nitro na hora e
  somam **+400** pontos (renascem em 40 s)
- **Bússola do próximo repositório**: seta girando, nome e distância até a
  praça não visitada mais próxima
- **Chefão final: SEGV** — complete os 13 repos e libere o duelo no botão
  "ENFRENTAR O CHEFÃO": telegrafa, carga e janela de vulnerabilidade, 3
  corações contra 100 de vida em 90 s (atalho: `?boss=1`)
- **Trânsito com colisão**: carros circulam pelas avenidas e te atrapalham
- **Rampas com física de pulo**: decole, voe e aterrisse com fumaça (o salto
  só dispara no sentido de subida — o paredão segura o carro como um muro,
  inclusive de marcha à ré)
- **Som procedural** (WebAudio, sem arquivos): motor que responde à
  velocidade, cantada de pneu na derrapagem, chime ao visitar um repositório,
  blip de coleta e batida — mute com `M`
- **Marcas de derrapagem**, fumaça nos pneus e shake de câmera
- **Missão e cronômetro**: explore os 13 projetos, veja seu tempo, sua
  pontuação e o recorde salvo no navegador
- **Minimapa** em tempo real com praças, rampas, trânsito e sua posição
- **HUD** com velocidade, nitro, pontos/combo, progresso e painel do repositório
- **Controles de toque** para celular (com botão DERRAPA) e **suporte a
  gamepad** (analógico + botões)
- **Qualidade adaptativa**: detecta mobile/GPU fraca e reduz sombras/pixel ratio (sem SMAA)
- **Timestep fixo** de física (60 Hz) e limpeza de recursos ao sair

## Como jogar

| Ação | Tecla |
|---|---|
| Acelerar | `W` / `↑` |
| Ré / frear | `S` / `↓` |
| Virar | `A` `D` / `←` `→` |
| Freio de mão | `Espaço` |
| Nitro | `Shift` |
| Abrir o repositório | `E` |
| Ligar/desligar som | `M` |
| Gamepad | analógico + botões (A = acelerar, B = frear, R1 = nitro, LB = freio de mão) |

No celular aparecem botões na tela, incluindo **DERRAPA**. O contador no topo
mostra quantos repositórios você já visitou — complete os 13 para fechar a
missão. Derrapar, coletar N2O e visitar repositórios pontuam: façam o maior
recorde de pontos antes que o tempo acabe.

## O Chefão

Depois de explorar os 13 repositórios, o botão **ENFRENTAR O CHEFÃO** libera o
duelo final contra **SEGV**, a máquina caçadora. Atalho direto para o combate:
`index.html?boss=1`.

- SEGV **persegue**, **telegrafa** (olho piscando + beep) e parte para a
  **carga** — mais rápida que o seu carro; desvie!
- Enquanto ele se **recupera** (2,2 s parado), arremesse o carro nele:
  **-20 de vida** (-30 com nitro)
- Isca a carga contra um **prédio**: ele leva **-15** e fica atordoado
- Encostar fora da janela de vulnerabilidade custa **1 coração**
- Ele tem **100 de vida**; você tem **3 corações** e **90 segundos** — use o
  nitro e os coletáveis de N2O a seu favor
- Vitória vale **+5.000 pontos**; a derrota tem **TENTAR DE NOVO** (reinicia
  só a luta, sem perder seu progresso)

## Jogar online

https://francoscorporation.github.io/repo-racer/

## Stack

- **Three.js** (r160, via CDN) — cena, luzes com sombras, reflexos (IBL),
  sprites, pós-processamento (bloom)
- **WebAudio** — som do motor e dos pneus gerado em tempo real
- **HTML/CSS/JS puro** — sem build, sem dependências instaladas
- **GitHub Pages** — hospedagem estática

## Rodar localmente

```bash
python3 -m http.server 8080
# abra http://localhost:8080
```

## Estrutura

```
index.html   # o jogo inteiro (cena, física arcade, áudio, HUD, controles)
preview.png  # screenshot usado no README
```

## Licença

MIT — veja [LICENSE](LICENSE).
