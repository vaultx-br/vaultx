# Arquitetura da source

## Objetivo

O VACUM instala e opera um Vaultwarden recuperável em uma única VM Ubuntu. A solução evita uma segunda instância do aplicativo: cria uma cópia consistente do SQLite, reúne anexos e chaves RSA e envia snapshots criptografados pelo Restic para um ou mais destinos S3.

O objetivo original não é apenas “ter backup”, mas reconstruir uma VM destruída com pouca intervenção, baixo RTO e RPO mensurável. O ciclo arquitetural completo é:

```text
instalar → operar → sincronizar configuração → copiar → destruir → restaurar → reiniciar → validar
```

A recuperabilidade é o critério principal: snapshot sem restauração testada é evidência incompleta.

## Árvore canônica

```text
.source/
├── _main/
│   ├── .bin/vacum              # loader local/remoto
│   ├── .cloudflare/index.js    # endpoint público /install
│   └── .web/index.html         # página para navegador
├── _vacum/
│   ├── .cmd/                   # CLI, instalação, configuração e sync
│   ├── .bkp/                   # imagem, backup, restore e cron
│   └── docker-compose.yml      # stack de produção
├── _env/
│   ├── _sample/                # contratos públicos sem valores reais
│   ├── _secrets/               # origem plaintext local e ignorada
│   ├── genesis.age             # recuperação cifrada da identidade age
│   └── secrets.age             # pacote cifrado de configuração
└── _test/README.md             # contrato; artefatos de ensaio são locais
```

## Componentes em execução

```text
Internet
   │
Cloudflare Tunnel
   │ rede Docker privada
   ├── Vaultwarden ── volume vaultwarden-data
   ├── ntfy
   └── Backup SVC ── leitura /data ── Restic ── S3
```

- `vaultwarden`: serviço principal e único dono funcional dos dados.
- `cloudflared`: única borda web; o Compose não publica portas da aplicação.
- `ntfy`: destino de notificações do job de backup.
- `backup-svc`: monta os dados como somente leitura, usa staging próprio e executa backup/restore.

## Contratos de host

| Caminho | Responsabilidade | Proteção esperada |
|---|---|---|
| `/opt/vacum-src` | clone da source | árvore Git limpa para `doctor` |
| `/opt/vaultwarden/.vws` | Compose e build do Backup SVC | acesso administrativo |
| `/opt/vaultwarden/_secrets` | identidade privada age recuperada pelo Genesis | diretório privado |
| `/run/vaultwarden/secrets` | configuração materializada a cada boot | `root:root`, diretório `700`, arquivos `600` |
| `/usr/local/bin/vacum` | entrada da CLI | link para o loader do clone |
| `/usr/local/libexec/vacum-*` | materialização e sincronização | executáveis instalados pelo bootstrap |

## Modelo de configuração

`genesis.age` contém um script cifrado por senha que restaura `age.key` e `age.pub`. Essa identidade descriptografa `secrets.age`, um `tar.gz` cifrado com:

```text
backup.env
cloudflared.env
git.env
vaultwarden.env
restic/[nome].env
```

`runtime-config.sh` extrai o pacote em memória temporária, valida os arquivos obrigatórios e instala cópias protegidas em `/run`. Os destinos nomeados são ordenados lexicalmente e materializados em variáveis internas `RESTIC_N_*`; `RESTIC_N_NAME` preserva o nome usado pela CLI.

Cada container recebe somente o arquivo necessário. `git.env` permanece no host. Valores reais nunca pertencem à documentação, aos exemplos, aos argumentos do Git ou aos logs.

## Estado persistido e estado reconstruível

- Persistido: volume do Vaultwarden, identidade age em `/opt/vaultwarden/_secrets`, clone e Compose instalado.
- Reconstruível: `/run/vaultwarden/secrets`, recriado por `vacum-runtime-config.service` antes do Docker.
- Externo: snapshots Restic e repositório Git com os artefatos cifrados.
- Excluído do backup por decisão: Vaultwarden Sends.

## Entradas compartilhadas

- `.source/_main/.bin/vacum`: no clone, delega à CLI; fora dele, baixa o instalador remoto.
- `.source/_vacum/.cmd/cli`: concentra comandos administrativos e defaults de caminhos.
- `.source/_vacum/.cmd/bootstrap.sh`: ponto único de preparação do host e subida inicial.
- `.source/_vacum/.cmd/runtime-config.sh`: ponto único de materialização segura.
- `.source/_vacum/.bkp/backup`: ponto único do backup manual e agendado.
- `.source/_vacum/.bkp/restore`: ponto único da restauração dentro da imagem de backup.

## Dependências e responsabilidades

| Camada | Dependências principais | Responsabilidade |
|---|---|---|
| Distribuição | Cloudflare Worker, GitHub raw, curl/wget | entregar página ou loader |
| Host | Ubuntu, systemd, Docker/Compose, age, Git, SSH/UFW | provisionar, proteger e materializar configuração |
| Aplicação | Vaultwarden, cloudflared, ntfy | servir o cofre, criar a borda e notificar |
| Proteção | SQLite, Restic, storage S3 | produzir, reter e recuperar snapshots |
| Administração | CLI Shell | concentrar operação e diagnóstico |

## Critérios arquiteturais de aceite

Uma implementação só fecha o ciclo quando prova:

- instalação em Ubuntu limpo;
- nenhuma porta da aplicação publicada diretamente;
- configuração recriada após reboot;
- snapshot remoto consultável;
- recuperação de banco, anexos e chaves RSA em volume vazio;
- SQLite íntegro, login funcional e anexo recuperável;
- `check` e `doctor` aprovados depois do restore e reboot;
- RTO e RPO observados registrados.
