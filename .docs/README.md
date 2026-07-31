# Documentação oficial VACUM

Toda a documentação vigente está organizada por público em apenas duas áreas:

```text
.docs/
├── Develop/  # source, arquitetura, pipelines, decisões, segurança e testes
└── Product/  # instalação, uso, operação, backup, recuperação e release
```

## Para desenvolver

Acesse [`Develop/README.md`](Develop/README.md).

| Tema | Documento |
|---|---|
| Arquitetura e contratos | [`Develop/architecture.md`](Develop/architecture.md) |
| Pipelines internas | [`Develop/pipeline.md`](Develop/pipeline.md) |
| Decisões positivas, negativas e substituídas | [`Develop/decisions.md`](Develop/decisions.md) |
| Segurança e testes | [`Develop/security-and-tests.md`](Develop/security-and-tests.md) |

## Para usar e operar

Acesse [`Product/README.md`](Product/README.md).

| Tema | Documento |
|---|---|
| Instalação | [`Product/installation.md`](Product/installation.md) |
| Comandos e rotina | [`Product/operations.md`](Product/operations.md) |
| Backup e recuperação | [`Product/backup-and-recovery.md`](Product/backup-and-recovery.md) |
| Release e rollback | [`Product/release.md`](Product/release.md) |

## Regras de manutenção

- Novo conteúdo técnico pertence a `Develop/`.
- Instrução para usuário ou operador pertence a `Product/`.
- Decisão substituída é marcada como histórica dentro de `Develop/decisions.md`, não mantida como runbook paralelo.
- Não duplicar instruções: escolha uma fonte principal e use links.
- Nunca documentar valores reais de ambiente, tokens, senhas, chaves, bancos ou anexos.
- Código e testes em `.source/` são a verdade final quando houver divergência.
