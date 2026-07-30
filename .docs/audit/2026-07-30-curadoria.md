# Curadoria de arquitetura — 2026-07-30

## Decisão

A árvore canônica é:

```text
.source/
├── _main/       # distribuição pública: Worker, página e loader
├── _vacum/      # operação: Compose, bootstrap, backup e comandos
├── _secrets/    # `config.age` e o exemplo público; nunca segredo aberto
└── _test/       # material local ignorado pelo Git
```

O fluxo canônico é `Worker → .bin/vacum → .cmd/install.sh → .cmd/bootstrap.sh → Compose`. O Worker passou a entregar `.source/_main/.bin/vacum`, que é o caminho real do loader.

A arquitetura de produção permanece uma VM com Docker Compose privado: `cloudflared` é a única borda, `vaultwarden` conserva estado em `vaultwarden-data`, `backup-svc` lê esse volume e `ntfy` recebe notificações internas. Não usar um segundo Vaultwarden para backup: a cópia consistente SQLite e os arquivos necessários são suficientes e evitam estado concorrente.

## Contratos operacionais e segurança

- `genesis.age` recupera apenas a chave age; `config.age` recupera a configuração em `/run/vaultwarden/config.env` (modo `600`). Não persistir `config.env`, chave age, Genesis, PAT ou QR no repositório.
- A agenda tem uma única fonte: `entrypoint.sh` grava o crontab a partir de `BACKUP_HOUR` e `BACKUP_MINUTE`. O arquivo `crontab` estático foi removido do build.
- O contrato de nós de backup é `RESTIC_N_{ENABLED,REPOSITORY,ACCESS_KEY,SECRET_KEY,PASSWORD}`. As variáveis `GIT_N_*` foram removidas do exemplo porque não têm consumidor; `git-sync.sh` recebe o PAT por arquivo explícito.
- `BACKUP_MAX_GB` é detecção pós-upload, não uma quota preventiva. Configure quota, versionamento/lifecycle e credencial restrita ao bucket no R2; trate o alerta do job como defesa adicional.
- Antes da produção, substitua `ADMIN_TOKEN` por hash Argon2 PHC e use token Cloudflare e credenciais R2 com menor privilégio.

## Pipeline de validação

1. Local: `bash -n` para scripts Bash, `sh -n` para scripts POSIX, `node --check` para o Worker e `docker compose config -q` usando configuração temporária.
2. Infra de teste: executar um backup real em R2 e confirmar snapshot, retenção e notificação ntfy.
3. Recuperação: VM limpa, Genesis e `config.age`; restaurar o último snapshot antes de iniciar o Compose e verificar login, anexos e chaves RSA. Esse teste determina RTO/RPO real.
4. Produção: validar Tunnel com token real e monitorar falha do job, tamanho do repositório e idade do último snapshot.

As etapas 2–4 continuam pendentes de credenciais/infra reais; não foram declaradas como validadas.
