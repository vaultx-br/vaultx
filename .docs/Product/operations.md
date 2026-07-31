# Operação da CLI

Execute comandos administrativos com `sudo` quando o nó já estiver instalado.

## Menu

```bash
vacum
```

Sem argumentos em terminal interativo, a CLI abre o menu. Em automação, use comandos explícitos.

## Comandos

### `vacum install`

Instala um nó novo. Não use para reparar ou atualizar um clone existente.

### `vacum check`

Verificação local rápida e sem mutação externa. Confirma clone, Compose, runtime protegido e serviços esperados.

```bash
sudo vacum check
```

### `vacum status`

Mostra containers e o snapshot mais recente por destino habilitado, incluindo idade aproximada.

```bash
sudo vacum status
```

### `vacum doctor`

Diagnóstico integrado somente leitura: sistema, Docker, disco, UFW/SSH, Git, Compose, serviços, saúde do Vaultwarden, agenda e acesso Restic.

```bash
sudo vacum doctor
```

Ele não cria snapshot. Uma falha deve ser corrigida antes de uma release ou teste destrutivo.

### `vacum backup`

Executa imediatamente o mesmo job agendado.

```bash
sudo vacum backup
```

O comando escreve em todos os destinos habilitados, aplica retenção e envia notificação. Uma trava impede execução concorrente no mesmo container.

### `vacum config`

Abre o menu para:

- URL/PAT Git;
- adicionar ou remover destino S3 nomeado;
- agenda, retenção e limite;
- URL, tópico e token ntfy;
- criar Genesis e `secrets.age` antes da instalação;
- abrir uma sessão de cadastro do Vaultwarden por três minutos.

**Cadastro por 3 min** recria o Vaultwarden com cadastro aberto e agenda o fechamento automático via systemd, mesmo que a sessão SSH caia. Uma sessão ativa não é prolongada silenciosamente. No nó instalado, ao salvar, a configuração é cifrada, aplicada e sincronizada. Credenciais são lidas sem eco.

### `vacum sync`

Alinha o nó ao `origin/master`:

```bash
sudo vacum sync
```

Antes de atualizar, envia qualquer alteração pendente de `secrets.age`. Depois executa fetch, reset exato para `origin/master`, remove somente arquivos não rastreados e não ignorados, reinstala scripts/Compose e recria os serviços. Arquivos ignorados não são apagados. Use `vacum seal` quando quiser apenas cifrar/enviar configuração sem atualizar a source.

O commit automático continua restrito a `secrets.age`. Se o remoto estiver indisponível, o commit local fica pendente e o timer tenta novamente; quando código novo já existe no remoto, o sincronizador faz rebase seguro antes do push.

### `vacum restore NODE [SNAPSHOT] [--yes]`

Restaura um destino nomeado ou índice e usa `latest` por padrão.

```bash
sudo vacum restore r2 latest
```

Consulte [`backup-and-recovery.md`](backup-and-recovery.md) antes de executar. O volume precisa estar vazio.

### `vacum test`

Executa validações de desenvolvimento da source. Não substitui `check`, `doctor` nem restore real.

## Rotina recomendada

### Diária/alerta

- Investigue qualquer notificação de falha.
- Use `status` para verificar idade do snapshot.
- Use `doctor` após mudança de VM, rede, credencial ou serviço.

### Após configuração

```bash
sudo vacum sync
sudo vacum check
sudo vacum doctor
```

Se a mudança afetar backup, execute também um backup manual e confirme o snapshot.

### Após atualização

1. Registre o commit/tag anterior.
2. Atualize a source conscientemente.
3. Execute `vacum test` e valide o Compose.
4. Reaplique/recrie apenas os serviços necessários.
5. Execute `check`, `doctor`, backup e restore em ambiente descartável.

## Códigos de falha relevantes

- comando inválido retorna erro de uso;
- `check`/`doctor` retornam falha se qualquer contrato obrigatório falhar;
- backup falha se nenhum destino está habilitado ou qualquer destino falha;
- falha somente da notificação de sucesso não apaga o fato de o backup ter concluído;
- restore falha para destino inexistente/duplicado, credencial incompleta, volume não vazio ou SQLite inválido.
