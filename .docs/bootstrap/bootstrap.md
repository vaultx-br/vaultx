# Bootstrap

## Escopo atual

`.source/bootstrap.sh prepara uma VM Ubuntu minimal antes dos containers:

1. Exige Ubuntu e execução como root.
2. Instala somente dependências ausentes: Docker, Compose, age, restic, curl, Git, jq, OpenSSL, UFW, fail2ban e unattended-upgrades.
3. Ativa Docker, fail2ban e atualizações automáticas.
4. Configura UFW com entrada bloqueada e saída permitida.
5. Mantém SSH/22 temporariamente aberto.
6. Mantém SSH na porta 22.
7. Desativa login SSH por senha e root.
8. Cria `/opt/vaultwarden` com permissão `700`.
9. Recebe `genesis.age` via stdin e restaura `_secrets/`.

## Uso

```bash
sudo bash .source/bootstrap.sh
```

SSH permanece na porta 22; a segurança vem de chave SSH, sem senha/root, UFW e fail2ban.

## Regras

- Não executar o bootstrap sem acesso ao console do provedor.
- Não fechar a porta 22 antes de validar a nova porta.
- Não versionar secrets abertos ou a chave privada age.
- `config.age` será descriptografado depois que `_secrets/age.key` existir.
- Vaultwarden, Backup SVC e Cloudflare Tunnel ficam para o Compose.

## Teste atual

Validação realizada com:

```bash
bash -n .source/bootstrap.sh
```

Ainda não há instalação de containers nem restauração de `config.age` nesta etapa.

## Teste automatizado

Para evitar interação no stdin:

```bash
sudo bash .source/bootstrap.sh \\
  --genesis-file .source/.test/genesis.age \\
  --password-file .source/.test/password.txt
```

`--password-file` exige permissão `600` e não deve ser usado com senha real em repositório.

## Validação na VM de teste

O fluxo automatizado foi validado em Ubuntu 24.04.4:

- Docker, fail2ban e unattended-upgrades ativos.
- UFW ativo, entrada padrão bloqueada e SSH/22 permitido.
- `genesis.age` normalizado e descriptografado.
- `_secrets/age.key` e `_secrets/age.pub` criados.
- Chave pública derivada validada contra `age.pub`.

A flag `--genesis-file` existe para testes automatizados; uso humano continua aceitando o conteúdo via stdin.

## Sends

O Vaultwarden usará Sends, mas o diretório de Sends fica fora do backup. A restauração recupera banco, anexos e chaves; Sends não fazem parte do estado persistido protegido.

## Step 2 — Compose

Decisão confirmada: Compose simples com `vaultwarden`, `cloudflared` e `ntfy`. O Backup SVC será adicionado quando sua lógica estiver pronta; não há placeholder. Secrets são lidos de `/run/vaultwarden/config.env`. O Compose não publica portas; o Cloudflare Tunnel é o ponto de entrada.

Imagens fixadas atualmente:

- `vaultwarden/server:1.37.1`
- `cloudflare/cloudflared:2026.7.3`
- `binwiederhier/ntfy:v2.26.3`

Atualizações devem ser explícitas e testadas; não usar `latest`.

## Integração atual

- Bootstrap + segurança: implementados e testados na VM.
- Bootstrap + Compose: ainda não integrados; o bootstrap ainda não restaura `config.age`, prepara `/run/vaultwarden/config.env`, copia o Compose nem executa `docker compose up -d`.
- Compose + Backup SVC: ainda não integrado; o serviço de backup ainda não existe.
- Compose + Cloudflared/ntfy/Vaultwarden: estrutura declarada, mas ainda não executada na VM.

## Plano de integração

O Backup SVC fica deliberadamente fora desta etapa. A ordem obrigatória é:

1. Bootstrap prepara e protege a VM.
2. `genesis.age` restaura `_secrets/age.key`.
3. `config.age` é descriptografado para `/run/vaultwarden/config.env`.
4. O Compose é instalado em `/opt/vaultwarden`.
5. `docker compose config` valida a configuração.
6. Vaultwarden, Cloudflared e ntfy são iniciados.
7. O stack é validado por health check e logs.
8. Somente depois é construído o Backup SVC.

Motivo: o backup precisa de um Vaultwarden funcional e de um caminho de dados definido; implementá-lo antes criaria dependências e testes artificiais.

> Correção de registro: a seção acima é planejamento pendente, não decisão implementada. A única parte confirmada até agora é que o Backup SVC não será construído antes da validação do stack principal.

## Integração Fase 1 — execução confirmada

O bootstrap agora restaura `config.age` usando `_secrets/age.key`, cria `/run/vaultwarden/config.env` com permissão `600`, copia o Compose para `/opt/vaultwarden`, valida a configuração e inicia os serviços.

Teste realizado na VM Ubuntu 24.04.4 com configuração temporária: Vaultwarden e ntfy ficaram em execução e nenhuma porta de aplicação foi publicada. Cloudflared iniciou, mas reiniciou porque o token usado no teste era fictício; o Tunnel real ainda precisa ser validado com token válido.

## Teste 2 — restauração interativa/automatizada

Foi corrigido o fluxo sem `--password-file`: o Genesis agora é descriptografado em `/run/vaultwarden/restore.sh` antes da execução, evitando pipe direto `age | bash`. A VM de teste foi executada com `--password-file` e configuração temporária; `_secrets/`, `config.env`, Compose e containers foram criados com sucesso.

## Caminho atual

A estrutura foi migrada para `.source/.base/.vacum/`. O bootstrap atual é `.source/.base/.vacum/.cmd/bootstrap.sh`; referências anteriores a `.source/bootstrap.sh` e `.source/.base/.sh/` são históricas.
