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

## Auditoria integral — estrutura, lógica e evolução

### Resumo executivo

A arquitetura é pequena e adequada ao objetivo: uma VM Ubuntu, quatro serviços em rede privada, SQLite copiado consistentemente e Restic para armazenamento externo. Não há benefício em introduzir Terraform, Ansible, Kubernetes, banco externo ou um segundo Vaultwarden antes de o fluxo atual provar recuperação real.

O sistema ainda não pode ser considerado pronto para disaster recovery. O maior vazio é funcional: existe criação de snapshot, mas não existe comando de restauração. Também há risco de falso sucesso quando todos os nós Restic estão desabilitados e um problema de ciclo de vida após reboot, pois a configuração necessária ao Compose vive somente em `/run` e não há unidade que a regenere.

### Mapa do sistema confirmado

```text
Worker /install
  -> loader público
  -> install.sh (clone + symlink)
  -> bootstrap.sh (host, SSH/UFW, Genesis, config runtime)
  -> Docker Compose
       ├── vaultwarden -> volume vaultwarden-data
       ├── cloudflared -> única entrada externa
       ├── ntfy -> notificações internas
       └── backup-svc -> SQLite .backup + arquivos + Restic

CLI local
  -> check/status/doctor/backup/test
```

A separação `_main` (distribuição), `_vacum` (operação), `_secrets` (material criptografado/exemplo) e `_test` (local e ignorado) é compreensível. O repositório tem aproximadamente 660 linhas de código/configuração não binária; o principal custo não é volume de código, mas contratos operacionais ainda incompletos.

### Achados priorizados

#### P0 — bloqueiam a promessa de recuperação

1. **Não existe restauração operacional.** Nenhum arquivo em `.source/` chama `restic restore`; o bootstrap sempre cria um volume vazio e inicia o Compose. Uma VM nova recupera configuração, mas não recupera o cofre. Implementar primeiro `vacum restore [nó] [snapshot|latest]`: validar destino vazio, restaurar para staging, verificar `db.sqlite3` com `sqlite3 ... 'PRAGMA integrity_check'`, copiar os dados para o volume e somente então iniciar o Vaultwarden. O teste de aceitação deve destruir um ambiente descartável e confirmar login, anexos e chaves RSA.

2. **Configuração runtime desaparece no reboot e não pode ser regenerada pelo fluxo atual.** O bootstrap escreve `/run/vaultwarden/config.env` (`bootstrap.sh:124-125`), mas não instala unidade de boot. Os containers existentes podem reiniciar com o ambiente já gravado, porém `docker compose config`, `up`, `doctor` e futuras recriações falham sem o arquivo. Reexecutar o bootstrap não resolve: ele recusa `/opt/vaultwarden/genesis.age` existente (`bootstrap.sh:70`). Criar uma unidade `systemd` mínima que descriptografe `config.age` com `age.key` antes de Docker/Compose, com arquivo temporário e modo `600`; separar “provisionar host” de “materializar runtime”, sem adicionar framework de configuração.

3. **Backup pode anunciar sucesso sem executar nenhum destino.** O script exige que exista ao menos uma variável `RESTIC_N_REPOSITORY`, mas ignora nós com `ENABLED=false` e termina com sucesso se todos estiverem desabilitados (`backup:22-40`). Contar nós efetivamente habilitados e falhar quando o total for zero.

#### P1 — segurança, integridade e disponibilidade

4. **Não há trava contra backups concorrentes.** Cron e `vacum backup` podem executar juntos no mesmo staging e repositório (`entrypoint.sh` + `cli:89`), causando limpeza concorrente, locks Restic e alertas falsos. Usar uma trava única no início do job (`flock` ou diretório atômico com trap); não criar fila ou scheduler novo.

5. **Falha de acesso ao Restic é tratada como repositório inexistente.** Qualquer erro em `restic snapshots` tenta `restic init` (`backup:33`), incluindo rede, credencial, lock ou corrupção. Separar “repositório não inicializado” dos demais erros e preservar a mensagem do Restic no alerta.

6. **O instalador remoto não é imutável.** O loader baixa sempre `master` (`.bin/vacum:10-13`), e o Worker também fixa implicitamente `master` (`worker/index.js:3-7`). Um comprometimento de branch muda o código executado por `curl | sh`. Publicar releases e baixar uma versão acompanhada de SHA-256; manter o comando curto apenas como conveniência explicitamente não reprodutível.

7. **`genesis.age` fica persistido sem necessidade operacional demonstrada.** O bootstrap grava o arquivo em `/opt/vaultwarden` (`bootstrap.sh:68-92`) e não o remove. Mesmo criptografado, ele amplia a superfície para ataque offline e contradiz a intenção documental de não persistir Genesis. Removê-lo após restauração bem-sucedida; conservar a cópia offline/QR sob controle do operador.

8. **Imagens usam tags, não digests.** As versões são explícitas, o que é melhor que `latest`, mas tags podem ser substituídas. Fixar digest depois de validar cada atualização e registrar versão + digest no mesmo commit.

9. **Ausência de healthchecks reais.** `depends_on` só ordena criação (`docker-compose.yml:16,37`), e `doctor` considera quatro containers “running” como saúde (`cli:49,65`). Adicionar healthcheck ao Vaultwarden e verificar nomes/health individualmente; não é necessário adicionar orquestrador.

10. **Validação de configuração é tardia.** Placeholders como `change-me`, formato de `DOMAIN`, token Admin sem Argon2, faixa de hora/minuto, retenção e limite só falham durante ou depois da subida. Fazer uma validação curta no bootstrap antes de escrever `/run` e antes de modificar serviços.

11. **Notificação de sucesso faz parte do resultado do job.** Se o snapshot concluir e apenas o ntfy falhar, `notify default` encerra o job com erro; isso mistura falha de observabilidade com falha de backup. Registrar “backup concluído, alerta falhou” separadamente, mantendo exit code/documentação coerentes. A notificação de falha já é best-effort.

#### P2 — diagnóstico, manutenção e coerência

12. **`doctor` contém verificações que quase sempre passam, mas não diagnosticam o contrato anunciado.** `df -Pk /opt` não aplica limite mínimo (`cli:58`); `git diff --quiet` ignora arquivos não rastreados (`cli:63`); quatro IDs em execução não garantem os quatro serviços corretos. Definir um limiar simples de disco, usar `git status --porcelain` e comparar nomes/estado/health.

13. **Teste automatizado é insuficiente.** `test-cli.sh` procura strings no código, então valida implementação textual, não comportamento. Manter um único teste Shell pequeno com comandos falsos em `PATH` para provar: zero nós habilitados falha, um nó bem-sucedido notifica sucesso e falha Restic propaga erro. Adicionar teste do Worker para `/install`, `/install/`, raiz e upstream indisponível apenas se o endpoint continuar sendo mantido.

14. **Documentação e endpoint divergem.** Documentos antigos anunciam a raiz `/`, mas o Worker aceita somente `/install` (`worker/index.js:14-16`); a página atual usa `/install`. Escolher `/install` como contrato canônico e corrigir referências históricas ativas, ou aceitar também `/` com uma condição adicional.

15. **Comentário de configuração está obsoleto.** `example.config.env:31` diz que `NTFY_TOKEN` não é usado, mas `backup:11` já o consome. Corrigir o comentário para evitar configuração equivocada.

16. **Falha de instalação deixa estado que impede nova tentativa.** Clone e symlink são criados antes do bootstrap (`install.sh:26-43`); se o bootstrap falhar, nova execução recusa o target existente. Em falha anterior ao primeiro `compose up`, remover apenas o clone/symlink criados pela execução ou oferecer mensagem explícita de retomada. Não apagar automaticamente um ambiente já inicializado.

17. **Configuração local observada diverge do exemplo.** O `config.env` local ignorado ainda contém chaves `GIT_1_*`, enquanto o contrato documentado as removeu. Como esse arquivo não é persistente nem foi descriptografado de `config.age` durante a auditoria, isto é apenas um alerta local: regenerar o arquivo a partir do contrato antes do próximo `config.age`.

### Pontos positivos

- SQLite é copiado com `.backup`, evitando cópia inconsistente do banco ativo.
- O volume de dados é somente leitura no Backup SVC e nenhuma porta de aplicação é publicada.
- Secrets runtime são escritos atomicamente com modo `600`.
- Imagens têm versões explícitas e o Compose passou na validação estrutural.
- O contrato Restic suporta múltiplos destinos sem abstração adicional.
- UFW, SSH sem senha/root, fail2ban e atualizações automáticas formam uma base de host razoável.
- Git Askpass evita PAT em URL/argumentos; arquivos de teste e secrets abertos estão ignorados.

### Simplificações e otimizações

- **delete:** remover o pacote `restic` do host no bootstrap; o código operacional usa Restic dentro do Backup SVC. Reintroduzir somente se o comando de restore for deliberadamente executado no host.
- **delete:** remover `openssl` e `jq` do host se nenhuma validação futura os consumir; hoje o `jq` usado está no container.
- **delete:** remover `backup-stage` nomeado. Staging é transitório; `tmpfs` no Compose reduz persistência de material restaurável e elimina limpeza residual. Definir limite de tamanho para não esgotar RAM; manter volume se o cofre real exceder a memória disponível.
- **shrink:** não manter simultaneamente documentação histórica contraditória como instrução ativa. Preservar o histórico, mas marcar seções antigas como substituídas e apontar para um único runbook atual.
- **yagni:** não adicionar Terraform/Ansible/Kubernetes/Postgres agora. Uma unidade systemd, um restore e um teste destrutivo cobrem o risco real com menos componentes.

Potencial conservador após correções: cerca de 20–35 linhas removíveis no host/configuração, sem dependência nova; o restore e seus testes necessariamente aumentarão o código porque entregam uma capacidade hoje ausente.

### Features e melhorias recomendadas, em ordem

1. **Restore verificável (`vacum restore`)** — feature obrigatória para cumprir o objetivo central.
2. **Teste periódico de recuperação em ambiente descartável** — mensal, com relatório de duração para medir RTO e idade do snapshot para medir RPO.
3. **Materialização de config no boot** — unidade systemd curta e idempotente.
4. **Status de backup confiável** — registrar último sucesso localmente ou consultar Restic; alertar por idade máxima, não apenas por falha imediata.
5. **Pré-validação de configuração** — recusar placeholders, valores inválidos e zero destinos habilitados.
6. **Releases verificadas** — versão e checksum no loader.
7. **Snapshot de volume da nuvem como segunda camada opcional** — somente depois do restore Restic funcionar; não substitui backup externo criptografado.
8. **Segundo destino Restic** — implementar por configuração apenas quando houver orçamento/necessidade de independência de provedor; o loop já suporta isso.

### Plano executável completo

#### Fase 1 — corrigir verdade do backup

- Falhar com zero nós habilitados.
- Adicionar lock global ao job.
- Diferenciar Restic não inicializado de indisponível.
- Corrigir comentário `NTFY_TOKEN`.
- Criar um teste comportamental mínimo para esses ramos.

**Aceite:** duas execuções simultâneas não corrompem staging; zero destinos retorna erro; indisponibilidade não tenta inicializar; um snapshot real aparece no R2 e alerta corretamente.

#### Fase 2 — entregar recuperação

- Adicionar comando `restore` com confirmação explícita e recusa de volume não vazio.
- Restaurar para staging, validar integridade SQLite e arquivos esperados.
- Popular `vaultwarden-data` antes de subir o Vaultwarden.
- Executar ensaio em VM limpa e registrar RTO/RPO medidos.

**Aceite:** VM descartável recupera login, itens, anexos e chaves a partir apenas do Genesis, repositório Git e Restic.

#### Fase 3 — fechar ciclo de reboot e upgrade

- Instalar unidade systemd para gerar `/run/vaultwarden/config.env` antes das operações Compose.
- Tornar instalação retomável sem apagar nó válido.
- Validar placeholders e política antes do `compose up`.
- Fixar imagens por digest e testar upgrade/rollback.

**Aceite:** reboot completo preserva serviços e permite `vacum check`, `status`, `doctor` e recriação de container sem bootstrap manual.

#### Fase 4 — observabilidade objetiva

- Healthcheck do Vaultwarden e checagem individual dos serviços.
- Limiar de espaço em disco e idade máxima do último snapshot.
- Alertas separados para backup, retenção/quota e notificação.

**Aceite:** `doctor` falha para container errado, Vaultwarden sem saúde, disco abaixo do limite, snapshot velho e R2 inacessível, sem executar backup destrutivo.

#### Fase 5 — endurecer distribuição

- Publicar release imutável com checksum.
- Alinhar `/install` em Worker, página e docs.
- Testar respostas do Worker e falha do upstream.

**Aceite:** uma instalação referencia versão identificável e detecta conteúdo alterado antes de executar.

### Validação desta auditoria

Executados com sucesso: sintaxe Bash e POSIX de todos os scripts, `node --check` no Worker, `test-cli.sh`, `docker compose config -q` com configuração temporária e `git fsck --no-dangling`. O Compose resolveu os quatro serviços esperados. `shellcheck` não está instalado. Não foram executados backup/restore reais, reboot de VM, Tunnel, R2 ou ntfy com credenciais; portanto disponibilidade externa, RTO, RPO e restaurabilidade continuam não confirmados.

A árvore já possuía alterações do usuário antes desta auditoria (`.cmd/cli` modificado; `.docs/commands.md` e `.cmd/test-cli.sh` não rastreados); elas foram apenas lidas e não alteradas.

## Execução do plano — implementação local

Foram implementadas e validadas localmente as partes executáveis do roadmap:

- Backup usa lock por container, falha com zero destinos habilitados e só tenta criar repositório quando `RESTIC_N_INITIALIZE=true` autoriza explicitamente.
- Falha exclusiva do ntfy após snapshot não transforma backup concluído em backup perdido.
- `vacum restore NODE [SNAPSHOT] [--yes]` restaura somente em volume vazio, valida SQLite e mantém o serviço parado se a recuperação falhar.
- Genesis passou a existir apenas no diretório temporário do bootstrap.
- `vacum-runtime-config.service` recria a configuração protegida em `/run` durante o boot.
- Bootstrap recusa placeholders críticos, horário inválido e ausência de destino Restic habilitado; dependências Restic/JQ/OpenSSL sem consumidor no host foram removidas.
- Instalação remove clone e symlink criados por ela quando o bootstrap não conclui.
- Vaultwarden recebeu healthcheck; `doctor` passou a validar serviços por nome, saúde, espaço mínimo e árvore Git incluindo arquivos não rastreados.
- `/install` foi confirmado como endpoint canônico e recebeu teste comportamental.

Validações locais concluídas: `bash -n`, `sh -n`, `node --check`, testes comportamentais de backup/lock, restore/volume não vazio e Worker, `vacum test`, `docker compose config -q`, presença de `curl` na imagem Vaultwarden e `git diff --check`. A imagem Backup SVC foi construída com `--network host`; um E2E local com Restic real criou snapshot, aplicou retenção, restaurou em diretório vazio, validou SQLite e confirmou os dados. A indisponibilidade intencional do ntfy não invalidou o backup concluído.

Continuam bloqueados por ambiente externo: snapshot e restore reais no R2, reboot em VM, medição RTO/RPO, Tunnel/ntfy reais, publicação de release com checksum, fixação de digests após teste de upgrade/rollback, segundo provedor e snapshot da nuvem. Esses itens não foram declarados concluídos. `RESTIC_N_INITIALIZE` deve permanecer `false`, sendo alterado para `true` apenas na criação consciente de um repositório vazio.

## Validação segura da configuração de produção

O arquivo local ignorado `.source/_secrets/config.env` foi validado sem registrar valores. Ele não é rastreado pelo Git e sua permissão local foi corrigida de `644` para `600`. O Compose de produção passou em `docker compose config -q`; há um nó Restic habilitado com os campos obrigatórios presentes, e o endpoint R2 resolveu DNS e aceitou conexão TCP/443.

Dois problemas permanecem: `ADMIN_TOKEN` não está em formato PHC Argon2 e ainda existem chaves locais obsoletas `GIT_*`. A consulta Restic somente leitura atingiu timeout de 120 segundos, apesar da conectividade TCP; portanto credenciais, bucket e acesso ao repositório R2 ainda não foram confirmados e nenhum backup foi disparado. Tokens Cloudflare/ntfy não foram impressos nem exercitados.

## Refinamento da configuração de produção

Os pontos locais foram corrigidos sem imprimir secrets:

- O valor existente de `ADMIN_TOKEN` foi convertido para Argon2id PHC com o preset OWASP do próprio Vaultwarden; a credencial lógica usada pelo operador permanece a mesma.
- As chaves obsoletas `GIT_*` foram removidas.
- O endpoint Restic estava configurado como `s3:http://`; foi corrigido para `s3:https://`. Isso explica o timeout anterior: a porta 80 não respondia, enquanto DNS, TCP/443 e TLS estavam funcionais.
- `config.age` foi recriptografado atomicamente com o destinatário local correspondente e validado por descriptografia + comparação byte a byte com `config.env`.

Após a correção, contrato, Compose e materialização runtime passaram; o runtime resultou em `600:root:root`. `restic snapshots` agora responde imediatamente e informa que o repositório ainda não existe. Logo, endpoint e transporte estão corrigidos, mas o primeiro `restic init`/backup continua pendente de autorização explícita por escrever no R2. Nenhum snapshot ou notificação externa foi criado nesta etapa.

## Refatoração para `secrets.age` e nós nomeados

`config.age` foi substituído por `secrets.age`, um arquivo age contendo um tar comprimido com separação por consumidor. A configuração de produção foi migrada sem imprimir valores; os legados `config.env`, `config.age` e `example.config.env` foram removidos. O artefato atual foi descriptografado e comparado com a origem temporária antes da limpeza.

Os nós Restic usam `restic/[nome].env`; o atual foi migrado para `restic/r2.env`. O runtime gera índices apenas para compatibilidade com o job. Adicionar ou remover um arquivo nomeado altera automaticamente o conjunto de destinos.

A sincronização automática usa um timer de cinco minutos e commita exclusivamente `secrets.age`. `git.env` fica somente no host e não é injetado em containers. O fluxo foi validado para pacote inalterado, adição de `restic/oracle.env`, nova criptografia e acionamento do sincronizador. O push real não foi executado para evitar publicar o conjunto de alterações antes da revisão final.

A inicialização Restic passou a ocorrer automaticamente somente diante do erro explícito de repositório ausente. Build e E2E local confirmaram init automático, snapshot e consulta posterior sem flag manual. A validação R2 real permanece pendente porque ela escreve no bucket.

## Wizard interativo de configuração

O instalador passou a oferecer um menu depois da materialização de `secrets.age` e antes do primeiro `compose up`. O mesmo fluxo está disponível posteriormente em `vacum config`. As opções implementadas são Git, adicionar/remover S3 nomeado, política de backup e ntfy; entradas sensíveis não têm eco. Alterações são gravadas atomicamente, seladas e aplicadas aos serviços, com push retomável pelo timer.

O caminho interativo foi validado em pseudo-TTY adicionando `restic/oracle.env` e alterando hora/minuto/retenção/limite, seguido de verificações nos arquivos resultantes. Valores de política exigem inteiros, hora/minuto respeitam suas faixas e retenção/limite devem ser positivos.
