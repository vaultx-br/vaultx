# Backup e recuperação

## Conteúdo protegido

- cópia consistente de `db.sqlite3` por SQLite `.backup`;
- diretório `attachments`, quando existente;
- arquivos `rsa_key*`.

Sends não são incluídos.

## Política padrão

| Item | Padrão |
|---|---|
| Horário | 03:33 |
| Fuso | America/Fortaleza |
| Retenção diária | 30 |
| Retenção mensal | 12 |
| Limite lógico | 4 GiB por destino |

Altere a política com `vacum config`. O Restic cifra, deduplica e aplica retenção separadamente em cada destino nomeado. Configure quota/lifecycle no provedor para um limite rígido.

## Verificar backups

```bash
sudo vacum status
sudo vacum doctor
```

Para uma prova com escrita:

```bash
sudo vacum backup
sudo vacum status
```

A presença do snapshot não basta. Programe restaurações periódicas em volume ou VM descartável.

## Restore operacional

> O restore exige volume vazio e para o Vaultwarden. Não execute sobre o volume de produção preenchido.

1. Confirme o destino e snapshot desejados.
2. Confirme que existe cópia válida e que o Genesis/configuração correspondente estão disponíveis.
3. Prepare um volume vazio ou ambiente descartável.
4. Execute:

```bash
sudo vacum restore r2 latest
```

Use o ID explícito no lugar de `latest` quando uma release registrar um snapshot específico.

O VACUM restaura em staging, exige `db.sqlite3`, executa `PRAGMA integrity_check` e só copia os dados depois da validação. Em falha, o Vaultwarden permanece parado.

## Validação pós-restore

```bash
sudo vacum check
sudo vacum doctor
```

Valide fora da CLI:

- login;
- quantidade e abertura de itens/pastas;
- download de um anexo conhecido;
- domínio HTTP;
- hashes de anexo e chave RSA quando houver baseline seguro;
- reboot seguido de novo `check` e `doctor`.

## Disaster recovery de VM perdida

```text
VM Ubuntu limpa
  → instalar VACUM com Genesis compatível
  → materializar secrets.age
  → garantir volume Vaultwarden vazio
  → restaurar snapshot registrado
  → iniciar/validar Vaultwarden
  → reboot
  → check + doctor + validação funcional
```

A instalação padrão sobe o Compose. Em um desastre, planeje a sequência para não popular o volume antes do restore; se o Vaultwarden já criou dados, recrie deliberadamente um volume vazio em vez de contornar a proteção.

## RTO e RPO

- **RTO:** meça desde o início da recuperação até Vaultwarden saudável e login validado.
- **RPO observado:** idade do snapshot escolhido no início do restore.

Ensaios históricos do projeto observaram recuperação em dezenas de segundos para um cofre pequeno, mas isso não é garantia. Registre medidas do seu volume e da sua rede em cada teste.

### Baseline histórico comprovado

Em ensaio remoto destrutivo, três rodadas recuperaram banco e chaves; a rodada final também recuperou um anexo real. Os RTOs observados foram 46, 42 e 42 segundos. Na rodada final, o snapshot tinha 37 segundos no início da recuperação. Foram aprovados SQLite, hashes, login, download, domínio, `check` e `doctor`.

Use esses números apenas como baseline histórico de um cofre pequeno. A meta oficial de cada ambiente deve ser definida e revalidada pelo operador.

## Falhas e ação

| Falha | Ação segura |
|---|---|
| backup já em execução | aguarde; não remova o lock de um processo ativo |
| repositório inacessível | valide rede/credencial; não inicialize outro caminho por engano |
| limite atingido | revise retenção/quota antes de novo upload |
| volume não vazio | use outro volume vazio; não force sobrescrita |
| SQLite inválido | mantenha serviço parado e tente snapshot anterior |
| notificação falhou | confirme snapshot diretamente e repare ntfy separadamente |

## Frequência de prova

- Após mudança em backup, restore, imagem, configuração ou armazenamento: teste destrutivo obrigatório.
- Antes de promover release: teste destrutivo obrigatório com o snapshot candidato.
- Em operação estável: teste periódico em ambiente descartável, com RTO/RPO registrados.
- Após rotação de credencial: `doctor`, backup real e consulta do novo snapshot.
