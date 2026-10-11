# Política de segurança

## Escopo

Repo Racer é um jogo estático executado no navegador. Não há API própria nem
servidor que receba contas ou dados do jogador. O jogo carrega Three.js e WebLLM
de URLs versionadas com integridade SRI; o modo de IA opcional baixa pesos do
modelo diretamente do Hugging Face na primeira utilização.

Não insira tokens, senhas ou outros segredos no jogo ou em relatórios públicos.

## Reportar uma vulnerabilidade

Envie o relato pelo recurso **Security Advisories** deste repositório no GitHub.
Se o formulário privado estiver indisponível, procure o mantenedor pelo perfil
[FrancosCorporation no GitHub](https://github.com/FrancosCorporation) e não
publique detalhes exploráveis em uma issue pública antes de uma correção.

## Versões

O projeto mantém a versão publicada na branch `main`. Relatos sobre dependências
devem incluir o navegador, sistema operacional e a URL do arquivo afetado, sem
anexar tokens, cookies ou dados privados.
