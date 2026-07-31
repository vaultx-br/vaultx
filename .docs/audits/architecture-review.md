# Plano de fechamento pré-produção

## Compreensão

O VACUM está estruturalmente coerente e passa nas validações locais básicas, mas ainda não pode receber aval de produção. Existem três falhas funcionais que quebram sincronização ou recuperação, credenciais que precisam ser rotacionadas e validações externas que só podem ser concluídas em uma Oracle VM descartável.

Objetivo deste plano: chegar a uma decisão objetiva de **GO/NO-GO**, provando o ciclo completo:

```text
instalar → operar → sincronizar → copiar → destruir → restaurar → reiniciar → diagnosticar
```

## Organização por prioridade

```text
VACUM // FECHAMENTO PRÉ-PRODUÇÃO
│
├── FASE 0 — CONTER EXPOSIÇÃO
│   ├── manter .production/ fora do Git
│   ├── manter arquivos abertos em modo 600
│   ├── rotacionar Git PAT
│   ├── rotacionar token Cloudflare Tunnel
│   ├── rotacionar credenciais S3/Restic
│   ├── rotacionar token ntfy
│   └── confirmar menor privilégio de cada credencial
│
├── FASE 1 — CORRIGIR BLOQUEADORES FUNCIONAIS
│   ├── Git sync
│   │   ├── usar /opt/vacum-src ou VACUM_SOURCE como raiz
│   │   ├── não inferir a raiz a partir de /usr/local/libexec
│   │   └── testar commit exclusivo de secrets.age + retry de push
│   │
│   ├── Restore por nome
│   │   ├── resolver r2 → índice cujo RESTIC_N_NAME=r2
│   │   ├── rejeitar nome inexistente ou duplicado
│   │   └── manter suporte explícito ao snapshot/latest
│   │
│   └── Instalação em modo recovery
│       ├── materializar configuração sem iniciar Vaultwarden
│       ├── construir/disponibilizar a imagem de backup
│       ├── restaurar somente em volume vazio
│       ├── validar SQLite
│       └── iniciar o stack somente após restore bem-sucedido
│
├── FASE 2 — FECHAR TESTES LOCAIS
│   ├── substituir test-backup.sh textual por teste comportamental
│   ├── cobrir zero destinos habilitados
│   ├── cobrir concorrência/lock
│   ├── cobrir repositório ausente versus inacessível
│   ├── cobrir credencial inválida e falha de rede
│   ├── cobrir falha de backup, retenção e limite
│   ├── cobrir falha exclusiva do ntfy
│   ├── cobrir restore por nome
│   ├── cobrir destino não vazio e SQLite inválido
│   └── cobrir instalação normal e recovery
│
├── FASE 3 — ENSAIO NA ORACLE VM DESCARTÁVEL
│   ├── Provisionar
│   │   ├── criar VM Ubuntu limpa
│   │   ├── revisar VCN e regras de entrada
│   │   ├── permitir somente SSH necessário
│   │   └── manter aplicação sem portas públicas
│   │
│   ├── Instalar
│   │   ├── executar o endpoint /install
│   │   ├── recuperar a chave pelo Genesis
│   │   ├── materializar secrets.age
│   │   └── confirmar instalação sem intervenção inesperada
│   │
│   ├── Operar
│   │   ├── confirmar Vaultwarden saudável
│   │   ├── confirmar Tunnel como única borda web
│   │   ├── confirmar ntfy
│   │   └── confirmar agenda do Backup SVC
│   │
│   ├── Copiar
│   │   ├── executar sudo vacum backup
│   │   ├── confirmar snapshot remoto
│   │   ├── confirmar retenção e limite
│   │   └── confirmar notificação
│   │
│   ├── Recuperar
│   │   ├── destruir a VM ou usar uma segunda VM limpa
│   │   ├── instalar em modo recovery
│   │   ├── restaurar latest pelo nome do nó
│   │   ├── confirmar PRAGMA integrity_check
│   │   ├── validar login, itens, anexos e chaves RSA
│   │   └── registrar duração e idade do snapshot
│   │
│   └── Reiniciar
│       ├── reiniciar a VM recuperada
│       ├── confirmar rematerialização dos secrets
│       ├── confirmar reinício dos quatro serviços
│       ├── executar vacum check
│       └── executar vacum doctor
│
├── FASE 4 — ENDURECIMENTO DA ENTREGA
│   ├── publicar release imutável
│   ├── verificar checksum antes de executar o instalador
│   ├── deixar de baixar master diretamente
│   ├── fixar imagens por digest após teste de upgrade
│   └── documentar rollback mínimo
│
└── FASE 5 — PÓS-PRODUÇÃO
    ├── teste destrutivo periódico de recuperação
    ├── alerta por idade do último snapshot
    ├── snapshot da VM Oracle
    ├── segundo destino Restic
    ├── rotação automática de credenciais
    └── acompanhamento contínuo de RTO/RPO
```

## Montagem executável

| Ordem | Entrega | Validação mínima | Bloqueia próxima fase |
|---|---|---|---|
| 0 | Segredos rotacionados e protegidos | nenhum segredo aberto rastreável; permissões `600` | sim |
| 1.1 | Git sync corrigido | alteração em runtime gera somente commit de `secrets.age`; push falho é retomado | sim |
| 1.2 | Restore nomeado corrigido | `restore r2 latest` resolve o índice correto; nome inválido falha | sim |
| 1.3 | Modo recovery | VM limpa restaura antes do primeiro start do Vaultwarden | sim |
| 2 | Testes comportamentais | todos os ramos críticos executam sem rede real | sim |
| 3.1 | Instalação Oracle | quatro serviços no estado esperado e Tunnel funcional | sim |
| 3.2 | Backup real | snapshot remoto consultável e notificação recebida | sim |
| 3.3 | Restore destrutivo | cofre recuperado com banco, anexos e chaves íntegros | sim |
| 3.4 | Reboot | runtime volta, serviços sobem e `doctor` passa | sim |
| 4 | Distribuição reproduzível | release/checksum e imagens por digest validados | não para piloto; sim para produção endurecida |
| 5 | Resiliência contínua | execução periódica com RTO/RPO registrados | não |

## Critérios de decisão

### GO — produção

Todos devem ser verdadeiros:

- P0 corrigido e testado.
- Credenciais anteriormente abertas rotacionadas.
- Backup real criado e localizado no destino remoto.
- Restore destrutivo concluído em VM limpa.
- Login, itens, anexos e chaves RSA confirmados.
- Reboot concluído com rematerialização do runtime.
- `vacum check` e `vacum doctor` aprovados.
- RTO e RPO medidos e aceitos pelo operador.
- VCN sem portas públicas desnecessárias e Tunnel funcional.

### NO-GO — bloquear produção

Qualquer um é suficiente:

- sync aponta para diretório diferente do clone;
- restore por nome não resolve o destino correto;
- recovery exige inicializar o Vaultwarden antes da restauração;
- segredo aberto não rotacionado;
- backup remoto não pode ser consultado;
- restore não recupera banco, anexos ou chaves;
- reboot perde configuração ou serviços;
- `vacum doctor` falha em componente obrigatório.

## Opção escolhida

Executar o caminho mínimo em série:

```text
conter e rotacionar segredos
  ↓
corrigir Git sync
  ↓
corrigir restore por nome
  ↓
adicionar modo recovery
  ↓
criar testes comportamentais mínimos
  ↓
instalar em Oracle descartável
  ↓
executar backup real
  ↓
destruir e restaurar em VM limpa
  ↓
reiniciar e executar check/doctor
  ↓
medir RTO/RPO
  ↓
decidir GO/NO-GO
```

Essa opção foi escolhida porque corrige primeiro as falhas que tornam qualquer ensaio externo inválido. Release, digests e automações periódicas permanecem depois da prova funcional, sem introduzir infraestrutura nova antes de fechar o ciclo essencial de recuperação.

## Estado inicial confirmado

```text
Concluído localmente
├── sintaxe Bash/POSIX/JavaScript
├── Docker Compose válido com configuração de exemplo
├── build do Backup SVC
├── integridade Git
├── restore local básico + integrity_check
├── .production/ ignorado pelo Git
└── arquivo local de produção ajustado para modo 600

Pendente
├── correções funcionais da Fase 1
├── rotação de credenciais
├── testes comportamentais completos
├── ensaio Oracle
├── backup e restore remotos
├── reboot validado
└── RTO/RPO medidos
```

## Execução da Fase 0 — contenção

Validado localmente em 2026-07-31, sem exibir valores:

- `.production/` permanece ignorado e não possui arquivos rastreados pelo Git;
- todos os arquivos em `.production/` estão em modo `600`;
- os arquivos sensíveis locais ignorados encontrados em `.source/` também estão em modo `600`;
- nenhum PAT GitHub, access key AWS ou token equivalente foi localizado nos blobs do histórico pelos formatos comuns verificados.

A rotação do Git PAT, Cloudflare Tunnel, S3/Restic e ntfy, assim como a confirmação de menor privilégio nos provedores, continua pendente. Até essa confirmação externa, a Fase 0 e o aval de produção permanecem bloqueados.

### Validação com `.production/enviroments.env`

Executada em 2026-07-31, carregando os valores sem registrá-los nos comandos de validação:

- completude das variáveis e formato Argon2 do `ADMIN_TOKEN`: aprovado;
- autenticação/leitura do repositório Git: aprovada;
- token do Cloudflare Tunnel consultado diretamente com `cloudflared tunnel info`: aprovado;
- saúde interna e publicação real no ntfy: aprovadas;
- repositório Restic: falhou porque o objeto `config` não existe no bucket; requer inicialização ou correção do caminho;
- domínio público: HTTP `522`;
- causa local do Tunnel: o Compose entrega literalmente `${CF_TUNNEL_TOKEN}` como argumento, portanto o container rejeita o token e reinicia, apesar de a credencial real ser válida.

As permissões de escrita do Git e o menor privilégio nos painéis não foram alterados durante esse teste, para evitar mutação administrativa.
