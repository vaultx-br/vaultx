# Documentação VACUM

A documentação é separada pela responsabilidade de cada conteúdo:

```text
.docs/
├── architecture/  # contexto, objetivos e decisões estruturais
├── installation/  # instalação, bootstrap e ensaios de instalação
├── operations/    # comandos e rotinas executadas no ambiente
├── planning/      # trabalho futuro, critérios de aceite e prioridades
└── audits/        # análises datadas; evidência histórica, não runbook
```

## Fontes por responsabilidade

| Necessidade | Documento |
|---|---|
| Entender o objetivo original | [`architecture/original-brief.md`](architecture/original-brief.md) |
| Instalar um nó | [`installation/install.md`](installation/install.md) |
| Entender o bootstrap | [`installation/bootstrap.md`](installation/bootstrap.md) |
| Operar a CLI | [`operations/commands.md`](operations/commands.md) |
| Operar backups | [`operations/backup.md`](operations/backup.md) |
| Operar sincronização Git | [`operations/git-sync.md`](operations/git-sync.md) |
| Executar o fechamento pré-produção | [`planning/pre-production.md`](planning/pre-production.md) |
| Preparar e promover uma release | [`planning/release.md`](planning/release.md) |
| Consultar decisões e achados anteriores | [`audits/`](audits/) |

## Regras de manutenção

- Um documento pertence à pasta de quem o usa, não à fase em que foi criado.
- Instrução operacional vigente fica em `operations/` ou `installation/`.
- Trabalho ainda não confirmado fica em `planning/`.
- Auditorias são imutáveis e recebem data no nome quando forem periódicas.
- Evite repetir a mesma instrução: mantenha uma fonte principal e use links nas demais.
