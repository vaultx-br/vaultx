# Comandos VACUM

## `vacum install`

Instala um nó novo. Clona o repositório em `/opt/vacum-src`, instala o binário em `/usr/local/bin/vacum`, recebe `genesis.age`, executa o bootstrap e inicia o Compose. Recusa sobrescrever `/opt/vacum-src` existente.

## `vacum check`

Verificação curta e sem rede: confirma que o clone, o Compose em `/opt/vaultwarden/.vws`, a configuração runtime e os serviços esperados existem. Não inicia serviços, não faz push e não escreve em R2.

## `vacum status`

Resumo somente leitura: estado, health e uptime dos serviços; último snapshot Restic disponível por nó e sua idade. Não executa backup nem modifica retenção.

## `vacum doctor`

Diagnóstico completo, somente leitura:

- VM: Ubuntu, Docker/Compose, espaço disponível e configuração UFW/SSH.
- Git: clone local, remote `origin` e estado do branch.
- Stack: Compose válido, configuração runtime protegida e health dos serviços.
- R2/Restic: credenciais/configuração presentes, acesso ao repositório e último snapshot.
- Backup: serviço/schedule disponíveis e idade do último backup.

`doctor` falha se um componente obrigatório falhar. Ele não cria snapshot, não aplica retenção e não envia dados.

## Implementação — 2026-07-30

`check` valida o clone, o Compose, o runtime `root:root` modo `600` e os quatro serviços declarados. `status` mostra o estado do Compose e consulta o último snapshot de cada nó Restic habilitado. `doctor` verifica Ubuntu, Docker/Compose, disco, UFW/SSH, Git, Compose, job agendado e acesso Restic; agrega falhas sem chamar o job. `backup` executa explicitamente `/usr/local/bin/backup` no `backup-svc`.

## `vacum backup`

Executa agora o mesmo job diário: SQLite consistente, anexos e chaves RSA, Restic, retenção e notificação ntfy. Este é o comando para testar R2 e um backup real; ele escreve no repositório.

## `vacum test`

Comando de desenvolvimento, fora do menu principal. Valida sintaxe dos scripts e Compose; não substitui `check` ou `doctor`.

## `vacum restore NODE [SNAPSHOT] [--yes]`

Restaura `latest` ou o snapshot informado somente quando o volume do Vaultwarden está vazio. O comando exige confirmação salvo com `--yes`, para o Vaultwarden, restaura via imagem do Backup SVC, exige `db.sqlite3`, executa `PRAGMA integrity_check` e só então copia os arquivos e reinicia o serviço. Em falha, mantém o Vaultwarden parado para evitar iniciar dados parciais.

## `vacum sync`

Sela os arquivos em `/run/vaultwarden/secrets/` como `.source/_secrets/secrets.age` e chama o sincronizador Git. Se o conteúdo não mudou, não cria commit, mas ainda tenta enviar eventual commit pendente. O timer executa o mesmo fluxo automaticamente a cada cinco minutos.

## `vacum config`

Abre o mesmo menu interativo do instalador para Git, nós S3 nomeados, política de backup e ntfy. Ao salvar, executa imediatamente o fluxo de `vacum sync` e aplica a nova configuração aos serviços.
