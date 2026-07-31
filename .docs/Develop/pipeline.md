# Pipelines internas

## 1. Distribuição

```text
GET /install
  → Worker escolhe conteúdo pelo User-Agent
  ├─ navegador: .source/_main/.web/index.html
  └─ curl/wget: .source/_main/.bin/vacum
                    → baixa install.sh do repositório
```

O endpoint implementado é `/install` e `/install/`; a raiz retorna `404`. O Worker exige a variável `URL`, remove `.git` para montar URLs raw do GitHub e responde sem cache.

## 2. Instalação

```text
loader → install.sh → clone → symlink vacum → Genesis → bootstrap.sh → Compose
```

1. `install.sh` exige Ubuntu, obtém privilégio via `sudo` quando necessário e recusa destino existente.
2. Clona o repositório em `/opt/vacum-src` e cria `/usr/local/bin/vacum`.
3. Recebe `genesis.age` por arquivo ou colagem em terminal.
4. Opcionalmente abre a configuração antes da primeira subida.
5. Em falha do bootstrap, remove apenas clone e link criados por aquela execução.
6. `bootstrap.sh` instala dependências ausentes, habilita Docker, fail2ban e unattended-upgrades, ativa UFW e endurece SSH.
7. O Genesis é normalizado e descriptografado; seu script restaura a identidade age.
8. Systemd, Compose e scripts do host são instalados.
9. `runtime-config.sh` materializa `secrets.age` em `/run`.
10. Placeholders, agenda e presença de destino habilitado são validados.
11. Compose é copiado, validado e iniciado.

## 3. Configuração e sincronização

```text
vacum config
  → altera arquivos runtime com modo 600
  → vacum-secrets-sync
      → normaliza pacote
      → compara com secrets.age atual
      → cifra atomicamente se mudou
      → rematerializa runtime
      → recria consumidores de env
      → git-sync commit/push
```

O timer `vacum-secrets-sync.timer` repete o fluxo a cada cinco minutos. `git-sync.sh` recusa outros arquivos staged, permite commit apenas de `.source/_env/secrets.age`, usa `GIT_ASKPASS` com arquivos temporários em RAM, faz rebase seguro quando o remoto avançou e mantém commit local para retry quando o push falha.

`vacum sync` primeiro executa esse selo/retry e só então alinha a source exatamente a `origin/master`, limpa arquivos não rastreados sem tocar nos ignorados, reinstala os executáveis/Compose e recria os serviços. `vacum seal` executa somente o fluxo de configuração.

## 4. Boot

```text
systemd
  → vacum-runtime-config.service
      → descriptografa secrets.age
      → instala /run/vaultwarden/secrets com 700/600
  → Docker/Compose pode recriar containers
```

`/run` é temporário por projeto; a unidade de materialização torna reboot e recriação previsíveis.

## 5. Backup

```text
cron ou vacum backup
  → lock global no container
  → limpa staging
  → SQLite .backup
  → copia attachments e rsa_key*
  → para cada RESTIC_N habilitado
      → valida credenciais
      → consulta/inicializa somente se repositório ausente
      → verifica limite antes do upload
      → restic backup /stage
      → forget + prune agrupado por paths/tags
      → verifica limite depois do upload
  → notifica sucesso ou falha
  → limpa staging e lock
```

Defaults atuais: `03:33`, `America/Fortaleza`, 30 diários, 12 mensais e 4 GiB por repositório. A política é configurável. O limite no script é uma proteção lógica, não quota rígida: o provedor deve impor quota/lifecycle se o teto físico for obrigatório.

## 6. Restore

```text
vacum restore NODE [SNAPSHOT]
  → confirma operação
  → descobre volume e imagem
  → para Vaultwarden
  → exige volume vazio
  → resolve NODE por RESTIC_N_NAME ou índice
  → restic restore para staging temporário
  → exige db.sqlite3
  → PRAGMA integrity_check
  → copia para o volume
  → reinicia Vaultwarden somente após sucesso
```

A recusa de volume não vazio evita sobrescrita acidental. Se o restore falha após a parada, o Vaultwarden permanece parado para impedir inicialização com dados parciais.

## 7. Diagnóstico

- `check`: contrato local mínimo — clone, stack, runtime protegido e serviços declarados.
- `status`: estado do Compose e último snapshot de cada destino habilitado.
- `doctor`: Ubuntu, Docker, disco, firewall, SSH, Git, Compose, serviços, healthcheck, agenda e acesso aos snapshots.
- `test`: sintaxe e testes locais; não substitui os diagnósticos do nó.

## 8. Promoção

```text
source + testes
  → commit candidato
  → instalação em VM limpa
  → backup real
  → restore destrutivo
  → validações funcionais e reboot
  → RTO/RPO observados
  → tag/release associada ao snapshot provado
```

Uma tag de produção só deve unir código testado e o identificador do snapshot restaurado. O procedimento vigente está em [`../Product/release.md`](../Product/release.md).
