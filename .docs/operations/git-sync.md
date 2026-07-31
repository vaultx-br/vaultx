# Git sync

`.source/_vacum/.cmd/git-sync.sh` cria commit e faz push das alterações do repositório.

Uso:

```bash
.source/_vacum/.cmd/git-sync.sh /run/vaultwarden/git-pat
```

O PAT deve ser fine-grained, limitado ao repositório e com `Contents: Read and write`. O script usa `GIT_ASKPASS`, não coloca o PAT na URL nem nos argumentos do Git. Arquivos sensíveis bloqueados incluem chaves privadas abertas, PEM e senhas. `.source/_env/genesis.age` e `.source/_env/secrets.age` são cifrados e podem ser versionados; Genesis PNG e `_env/_secrets/` permanecem locais.

O script é acionado explicitamente por enquanto. Um watcher automático só deve ser adicionado se houver necessidade comprovada.

## Caminho atual

O script fica em `.source/_vacum/.cmd/git-sync.sh`; os caminhos anteriores são históricos.

## Sincronização automática de `secrets.age`

O contrato atual substitui o PAT avulso por `/run/vaultwarden/secrets/git.env`, com `GIT_URL` e `GIT_PAT`. O PAT não entra em nenhum container. `vacum-secrets-sync.timer` executa a cada cinco minutos: compara o conteúdo runtime com o pacote criptografado, gera `.source/_env/secrets.age` somente quando há mudança, cria commit contendo exclusivamente esse arquivo e tenta push. Se um push anterior falhar, a próxima execução tenta novamente mesmo sem nova alteração.

O pacote contém `backup.env`, `cloudflared.env`, `git.env`, `vaultwarden.env` e `restic/[nome].env`. Para adicionar um destino, crie por exemplo `/run/vaultwarden/secrets/restic/oracle.env`; o nome deve usar letras, números, `_` ou `-`. Execute `vacum sync` para envio imediato ou aguarde o timer. Quando há mudança, o fluxo sela, rematerializa os índices Restic e recria automaticamente os serviços que consomem env antes de tentar o push; uma indisponibilidade do GitHub não impede a aplicação local.

## Validação da raiz e retry — 2026-07-31

O sincronizador usa `/opt/vacum-src` ou `VACUM_SOURCE` como raiz explícita, sem inferir caminhos a partir da cópia instalada em `/usr/local/libexec`. O teste comportamental confirmou que o commit contém exclusivamente `.source/_env/secrets.age`, que uma indisponibilidade do remoto mantém o commit local e que a execução seguinte envia esse commit sem exigir nova alteração.
