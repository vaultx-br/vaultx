# VACUM — documentação oficial do produto

VACUM instala, protege, opera, copia e recupera uma instância Vaultwarden em uma VM Ubuntu usando Docker Compose, Cloudflare Tunnel, Restic e ntfy.

## Comece aqui

- [`installation.md`](installation.md): pré-requisitos, preparação e instalação.
- [`operations.md`](operations.md): comandos e rotina diária.
- [`backup-and-recovery.md`](backup-and-recovery.md): política, restauração e disaster recovery.
- [`release.md`](release.md): promoção e rollback de produção.

## O que o VACUM entrega

- host Ubuntu endurecido com SSH por chave, UFW, fail2ban e atualizações automáticas;
- Vaultwarden sem porta de aplicação publicada;
- entrada web por Cloudflare Tunnel;
- backup consistente do SQLite, anexos e chaves RSA;
- um ou mais destinos S3 criptografados pelo Restic;
- retenção, limite lógico e notificações ntfy;
- configuração cifrada e rematerializada a cada boot;
- CLI para diagnóstico, backup, configuração, sincronização e restore validado.

## Limites importantes

- Sends não fazem parte do backup.
- O limite de armazenamento do VACUM não substitui quota do provedor.
- Backup só é considerado comprovado após restore destrutivo testado.
- O endpoint oficial é `/install`; a raiz do domínio não é endpoint de instalação.
- O instalador atual acompanha `master`; use uma tag validada para rollback e não presuma distribuição imutável.
