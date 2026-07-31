# Linha do tempo de instalação

```text
┌──────────────────────────────────────────────────────────────┐
│                     VACUM // INSTALAÇÃO                      │
└──────────────────────────────────────────────────────────────┘

[ MÁQUINA SEGURA / WSL ]
        │
        ├─ 01. Criar genesis.age + QR
        │       .source/_vacum/.cmd/genesis.sh
        │
        ├─ 02. Criar config.env temporário
        │       DOMAIN / ADMIN_TOKEN / CLOUDFARE / R2 / GIT
        │
        ├─ 03. Criptografar config.env
        │       → .source/_secrets/config.age
        │
        ├─ 04. Apagar config.env aberto
        │
        └─ 05. Commit + push de config.age
                │
                ▼
[ GITHUB ]
        │
        ├─ Código VACUM
        └─ config.age criptografado
                │
                ▼
[ VM UBUNTU LIMPA ]
        │
        ├─ 06. Executar:
        │
        │   curl -fsSL https://vacum.brazill.org/ | sh
        │
        ├─ 07. Wizard:
        │       ├─ clona o repositório
        │       └─ recebe genesis.age por arquivo ou colagem
        │
        ├─ 08. Bootstrap:
        │       ├─ instala Docker, age, Restic, SSH, UFW
        │       ├─ protege SSH/22
        │       ├─ restaura age.key
        │       ├─ descriptografa config.age em /run
        │       └─ sobe Docker Compose
        │
        └─ 09. Serviços:
                ├─ Vaultwarden
                ├─ Cloudflare Tunnel
                ├─ ntfy
                └─ Backup SVC
                        │
                        ▼
[ OPERAÇÃO ]
        │
        ├─ Backup diário: 03:33 America/Fortaleza
        ├─ Restic → R2
        ├─ Retenção: 30 diários + 12 mensais
        ├─ Limite: 4 GiB
        └─ Alertas → ntfy
```

Quando o Worker Cloudflare estiver publicado, o comando curto também poderá usar a raiz:

```bash
curl -fsSL https://vacum.brazill.org/ | sh
```

## Endpoint vigente

As ocorrências da raiz acima são históricas. O endpoint implementado e validado é:

```bash
curl -fsSL https://vacum.brazill.org/install | sh
```
