# Segurança e validação

## Política de dados sensíveis

Nunca imprimir, copiar para documentação, anexar a issues ou incluir em comandos registrados:

- conteúdo de `_env/_secrets/`;
- valores de arquivos `.env` reais;
- senha do Genesis;
- identidade privada age;
- PAT Git, token de Tunnel/ntfy e credenciais S3;
- banco, anexos ou artefatos de `_test/`.

É seguro documentar somente nomes de variáveis, formatos, caminhos e permissões. `genesis.age` e `secrets.age` são cifrados e versionáveis por contrato, mas continuam material sensível: acesso ao repositório e backups deve ser restrito.

## Fronteiras de confiança

- Entrada pública: Worker e loader remoto.
- Entrada administrativa: terminal interativo da CLI e arquivos fornecidos ao bootstrap.
- Estado aberto: runtime em `/run`, acessível apenas a root.
- Estado cifrado: Git e destinos Restic.
- Containers: cada serviço recebe apenas seu env; dados do Vaultwarden são read-only para backup.

## Controles implementados

- `umask 077` nos fluxos que manipulam configuração.
- Arquivos runtime `600`, diretórios `700` e propriedade `root:root`.
- Escrita por arquivo temporário seguida de `mv` nos pontos de configuração.
- Leitura sem eco para credenciais interativas.
- PAT fora de URL e argumentos, via `GIT_ASKPASS` temporário em RAM.
- SSH sem senha e sem root; UFW deny incoming; fail2ban e atualizações automáticas.
- Nenhuma porta de aplicação publicada pelo Compose.
- Validação de volume vazio e SQLite antes de concluir restore.

## Matriz de testes

| Teste | O que prova | O que não prova |
|---|---|---|
| `bash -n` / `sh -n` | sintaxe dos scripts | comportamento ou infraestrutura |
| `test-cli.sh` | `doctor` não dispara backup e comando manual usa o job comum | diagnóstico real do host |
| `test-backup.sh` | checagem de limite ocorre antes do upload | integração Restic completa |
| `test-restore.sh` | nome, destino vazio e cópia após SQLite válido | restore remoto e login |
| `test-genesis.sh` | Genesis/pacote cifrado e ausência de arquivo de senha | custódia humana da senha |
| `test-config-signups.sh` | abertura por 3 minutos, timer e fechamento | cadastro real pelo domínio |
| `test-git-sync.sh` | commit exclusivo, retry e rebase quando o remoto avançou | permissões do provedor real |
| `test-sync-source.sh` | reset ao remoto, limpeza seletiva e preservação de ignorados | atualização real da VM |
| `test-worker.mjs` | `/install`, seleção por User-Agent e erro sem URL | disponibilidade pública |
| `vacum check` | instalação e permissões básicas | rede e escrita externa |
| `vacum doctor` | saúde integrada sem criar backup | restaurabilidade funcional |
| backup + restore destrutivo | ciclo de recuperação real | futuras execuções sem repetição periódica |

## Validação mínima de mudança

```bash
vacum test
git diff --check
git status --short
```

Mudanças em instalação, backup, restore, configuração ou segurança exigem também um ensaio comportamental do caminho alterado. Antes de release, usar VM/volume descartável, destino real e validação de login, banco, chaves e anexo.

## Revisão sem vazamento

Ao auditar:

1. Liste caminhos, não conteúdo sensível.
2. Não execute `env`, `set`, `cat *.env` ou comandos que ecoem argumentos secretos.
3. Valide presença, modo e formato sem mostrar valor.
4. Redirecione saída de ferramentas externas que possam repetir credenciais.
5. Limpe temporários em `/dev/shm` com `trap`.
6. Registre apenas resultado booleano e evidência não sensível.
