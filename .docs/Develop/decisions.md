# Decisões de engenharia

## Decisões positivas vigentes

| Decisão | Motivo |
|---|---|
| Uma VM e Docker Compose | Menor superfície operacional para o escopo atual. |
| Backup direto, sem segundo Vaultwarden | Evita concorrência de estado e custo sem melhorar consistência. |
| SQLite `.backup` | Produz cópia consistente com a aplicação ativa. |
| Dados montados read-only no Backup SVC | Limita o impacto do job sobre produção. |
| Restic por destino nomeado | Criptografia, deduplicação, retenção e múltiplos provedores sem lógica própria. |
| Cloudflare Tunnel sem portas publicadas | Mantém a aplicação fora da borda direta da VM. |
| Imagens com versão explícita | Evita atualização involuntária por `latest`. |
| Secrets separados por consumidor | Reduz exposição entre containers e mantém Git PAT no host. |
| Runtime em `/run` com materialização systemd | Secrets abertos não são persistidos como configuração comum e sobrevivem logicamente ao reboot. |
| Restore somente em volume vazio | Evita mescla ou sobrescrita destrutiva. |
| Lock único de backup | Impede concorrência entre cron e execução manual. |
| Push restrito a `secrets.age` | Impede que o automatismo publique alterações não relacionadas. |
| Teste destrutivo de recuperação | Snapshot existente não prova restaurabilidade. |

## Decisões negativas

Não introduzir agora:

- segundo container Vaultwarden como “espelho”;
- Kubernetes;
- Terraform ou Ansible para uma única VM;
- PostgreSQL externo apenas para backup;
- scheduler ou plataforma própria de monitoramento;
- abstrações para provedores além do contrato S3/Restic.

Esses itens só devem voltar à análise quando uma limitação medida do desenho atual justificar o custo.

## Decisões substituídas durante a evolução

Estas abordagens existiram no planejamento, mas não representam o contrato atual:

- `config.age` único foi substituído por `secrets.age` com arquivos separados por consumidor;
- variáveis Restic avulsas foram substituídas por `restic/[nome].env` e índices internos `RESTIC_N_*`;
- configuração runtime única foi substituída por `/run/vaultwarden/secrets/`;
- cálculo próprio de horário foi substituído pelo `crond` da imagem de backup;
- inicialização Restic por flag foi substituída por detecção restrita do erro de repositório ausente;
- referências antigas a `.base`, `.worker`, `_secrets/config.age` e scripts na raiz não são caminhos canônicos;
- `/` no domínio foi descartado como endpoint de instalação; o contrato é `/install`.

A documentação oficial não deve reintroduzir esses caminhos como instruções vigentes.

## Limites assumidos

- Sends não são protegidos pelo backup atual.
- A trava de backup é local ao container; múltiplos hosts apontando para o mesmo repositório exigem coordenação externa.
- O teto `BACKUP_MAX_GB` pode ser ultrapassado por um único upload; quota rígida pertence ao provedor.
- `doctor` observa contratos técnicos, mas não substitui login e abertura de itens/anexos após restore.
- RTO/RPO dependem do tamanho do cofre, rede, provedor e frequência efetiva dos snapshots.

## Pendências confirmadas para endurecimento

- O loader e o Worker ainda consomem o branch mutável `master`; distribuição reproduzível requer release fixa e verificação de checksum.
- Imagens têm tags fixas, mas ainda não digests imutáveis.
- Credenciais devem ser rotacionadas e ter menor privilégio antes de cada promoção relevante.
- Testes periódicos de restore e alerta por idade máxima do snapshot ainda precisam de rotina operacional formal.

## Decisão de mudança

Uma alteração de arquitetura deve responder, nesta ordem:

1. Qual falha observável ela corrige?
2. O contrato existente já oferece o ponto compartilhado correto?
3. A solução usa recurso nativo ou dependência já presente?
4. Existe um teste pequeno que falharia antes?
5. A mudança preserva não exposição de secrets e recuperação?

## Evidências históricas úteis consolidadas

Os ensaios concluídos provaram, em momentos diferentes da evolução:

- bootstrap e reboot em Ubuntu com systemd;
- Tunnel como borda única e quatro serviços em execução;
- snapshot remoto, retenção e verificação parcial de dados Restic;
- restore destrutivo do volume com SQLite íntegro;
- preservação de usuário, itens, pastas, anexo e chaves RSA;
- login, download, domínio, `check` e `doctor` após recuperação.

Essas evidências validam o desenho, mas não dispensam repetir o ensaio para cada release e conjunto de credenciais.
