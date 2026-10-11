# Plano de melhorias — Repo Racer

**Atualizado em:** 11/10/2026  
**Estado:** mudanças de código e documentação implementadas; aceite em navegador e container pendente.

## Documentos de referência

- `MELHORIAS.md` — consolidação ativa de segurança, operação e pendências deste repositório.
- `MELHORIAS-3D-E-IA.md` — registro histórico das melhorias de 3D, IA clássica e WebLLM.
- `MELHORIAS-LOOPING.md` — registro histórico do diagnóstico e validação do looping.
- `README.md` — instruções para jogar/rodar e índice dos documentos.

## Melhorias de experiência já incorporadas

- Materiais físicos para guias de meio-fio, faixas, barras, antenas e prédios; as sombras de prédios e objetos grandes usam o sol existente.
- Trânsito dinâmico tem colisão, faróis, setas e luzes de freio. O backlog antigo de carros estacionados foi substituído por tráfego móvel, que já dá movimento à cidade sem duplicar veículos.
- HUD mostra carregamento/estado e decisões do LLM, vida/tempo do chefão e, durante a caçada, quantos rivais continuam ativos. A biblioteca WebLLM não expõe uma métrica útil de “energia”; o progresso de carga e as decisões aplicadas são exibidos no lugar.
- As melhorias de looping, IA, leitura visual e otimização 3D estão detalhadas nos documentos históricos acima.

## Melhorias de segurança e operação desta rodada

- [x] Integridade SRI no import map para os 15 módulos exatos de Three.js/WebLLM carregados pelo jogo.
- [x] Servidor estático retorna 404 para caminhos inexistentes e serve `/LICENSE` como texto.
- [x] Cabeçalhos de segurança e política CSP alinhada aos imports CDN, WebGPU/WASM, workers e downloads dos pesos do modelo.
- [x] Imagem Nginx com versão fixada, sem preview/default `50x.html`, e Compose com rootfs somente leitura, capabilities mínimas e healthcheck.
- [x] CI para sintaxe do módulo embutido e build da imagem Docker.
- [x] `.gitignore`, `SECURITY.md` e índice de documentação.

## Pendências de aceite

- Fazer validação em navegador do CSP no carregamento normal e do LLM/WebGPU depois da alteração dos cabeçalhos.
- Fazer build/healthcheck do Compose e conferir as respostas HTTP 200/404 do Nginx.
- A execução do workflow depende de conseguir publicar o arquivo `.github/workflows/ci.yml` com credencial que inclua o escopo `workflow`.
- A divisão do `index.html` permanece adiada: o jogo estável usa deliberadamente um único arquivo e a mudança exigiria uma validação de regressão própria.

## Rodar localmente

```bash
python3 -m http.server 8080
# abra http://localhost:8080
```

Para servir com os cabeçalhos de produção:

```bash
docker compose up --build
# abra http://localhost:8080
```
