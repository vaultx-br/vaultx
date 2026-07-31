# VACUM — documentação de desenvolvimento

Esta pasta é a referência oficial para compreender, alterar e validar a source do VACUM. A documentação histórica permanece nas demais pastas de `.docs/`, mas pode descrever estados já substituídos.

## Mapa

- [`architecture.md`](architecture.md): componentes, diretórios, contratos e fluxo de dados.
- [`pipeline.md`](pipeline.md): pipelines de distribuição, instalação, configuração, backup, restore e release.
- [`decisions.md`](decisions.md): decisões positivas, negativas, limites e pendências confirmadas.
- [`security-and-tests.md`](security-and-tests.md): tratamento de secrets e estratégia de validação.

## Regra de verdade

1. Código e testes em `.source/` definem o comportamento implementado.
2. Estes documentos explicam esse comportamento.
3. Auditorias datadas registram evidência histórica, não instruções vigentes.
4. Planejamento não deve ser descrito como funcionalidade entregue.

## Antes de alterar

```bash
vacum test
bash -n .source/_vacum/.cmd/*.sh .source/_vacum/.cmd/cli
sh -n .source/_vacum/.bkp/backup .source/_vacum/.bkp/restore .source/_vacum/.bkp/entrypoint.sh
node .source/_main/.cloudflare/test-worker.mjs
```

Não abra, imprima ou inclua em logs `_env/_secrets/`, arquivos `*.env` reais, senhas, chaves, tokens, conteúdo descriptografado ou artefatos locais de `_test/`.
