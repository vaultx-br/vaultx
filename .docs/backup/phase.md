# Fase de Backup

## Decisões confirmadas

- Backup diário às `03:33`, no fuso `America/Fortaleza`.
- Retenção: 30 snapshots diários + 12 snapshots mensais.
- Limite máximo total: `4 GB` por bucket/repositório.
- Primeiro destino: Cloudflare R2.
- Nós adicionais serão configurados por índices `RESTIC_1_*`, `RESTIC_2_*` etc. dentro de `config.age`.
- Sends ficam fora do backup.
- Falhas, sucesso e limite atingido gerarão notificações via ntfy.

## Composição planejada

```text
Backup SVC
├── staging temporário
├── SQLite .backup consistente
├── anexos e chaves RSA
├── exclusão de Sends
├── Restic para cada nó habilitado
├── retenção por repositório
└── notificação ntfy
```

## Implementação inicial

Criados `.source/backup-svc/Dockerfile`, `backup.sh` e `entrypoint.sh`, integrados ao Compose.

O serviço monta os dados do Vaultwarden como somente leitura, cria o backup consistente do SQLite em staging, copia anexos e chaves RSA, exclui Sends, executa Restic para R2, aplica retenção e envia ntfy.

A execução real com credenciais R2 ainda não foi validada.

## Auditoria pendente

A implementação precisa de correções antes de ser considerada pronta:

- O script ainda usa variáveis únicas, não os nós indexados `RESTIC_N_*` definidos no contrato.
- O agendamento `date -d '03:33'` ainda não foi validado na imagem Alpine.
- Falhas são suprimidas pelo loop do entrypoint.
- `restore.sh` não tem limpeza garantida em toda falha.
- `config.env` deve ser escrito atomicamente.
- O restore automático e o limite R2 ainda não foram testados.

## Estrutura de implementação

```text
.base/
├── .sh/   # bootstrap e scripts shell
├── .bkp/  # Backup SVC
└── .vws/  # Compose/Vaultwarden stack
.test/     # artefatos temporários de teste
.source/   # config.age versionado
/genesis.sh
```

O bootstrap copia o Compose e `.bkp` para `/opt/vaultwarden` antes de iniciar o stack.

## Estrutura corrigida

```text
.source/
├── .base/
│   ├── .sh/
│   ├── .bkp/
│   └── .vws/
├── .test/
└── .secrets/
    └── config.age

.docs/
genesis.sh
```

`genesis.sh` permanece na raiz do projeto. O bootstrap fica em `.source/.base/.sh/` e usa caminhos relativos à nova estrutura.

## Auditoria — correções aplicadas

- Backup SVC agora percorre nós `RESTIC_N_*` habilitados.
- Falhas de nós não são ignoradas; o job termina com erro e notifica.
- Agendamento passou para `crond` às `03:33`, evitando cálculo não validado em Alpine.
- `config.env` é escrito em arquivo temporário e substituído atomicamente.
- `restore.sh` passou a ser removido pelo trap de saída.
- A construção padrão da imagem falhou por erro de rede do Docker ao acessar os repositórios Alpine. O build com `--network host` foi concluído; o Compose passou a usar rede host somente durante o build. A execução real do job e o R2 ainda não foram validados.
