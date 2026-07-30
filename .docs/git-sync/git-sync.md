# Git sync

`.source/.base/.sh/git-sync.sh` cria commit e faz push das alterações do repositório.

Uso:

```bash
.source/.base/.sh/git-sync.sh /run/vaultwarden/git-pat
```

O PAT deve ser fine-grained, limitado ao repositório e com `Contents: Read and write`. O script usa `GIT_ASKPASS`, não coloca o PAT na URL nem nos argumentos do Git. Arquivos sensíveis bloqueados incluem chaves, PEM, senhas e `genesis.age`; `config.age` criptografado pode ser versionado.

O script é acionado explicitamente por enquanto. Um watcher automático só deve ser adicionado se houver necessidade comprovada.

## Caminho atual

O script foi movido para `.source/.base/.vacum/.cmd/git-sync.sh`; os caminhos anteriores são históricos.
