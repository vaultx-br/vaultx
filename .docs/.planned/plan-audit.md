## Visão geral

O VACUM possui uma arquitetura enxuta e coerente, mas ainda entrega **backup**, não **disaster recovery completo**.

```text
VACUM
├── Distribuição
│   ├── Cloudflare Worker (/install)
│   ├── Página web
│   └── Loader remoto
├── Instalação
│   ├── Clone do repositório
│   ├── Bootstrap Ubuntu
│   ├── Segurança SSH/UFW
│   └── Descriptografia da configuração
├── Operação
│   ├── Vaultwarden
│   ├── Cloudflare Tunnel
│   ├── ntfy
│   └── Backup SVC
├── Persistência
│   ├── SQLite consistente
│   ├── Anexos
│   ├── Chaves RSA
│   └── Restic → R2
└── Administração
    ├── check
    ├── status
    ├── doctor
    ├── backup
    └── test
```

## Pipeline atual

```text
Usuário
  ↓
curl /install
  ↓
Worker entrega loader
  ↓
Loader baixa install.sh
  ↓
Instalador clona o projeto
  ↓
Bootstrap prepara Ubuntu
  ├── Docker
  ├── SSH/UFW/fail2ban
  ├── Genesis → age.key
  └── config.age → /run/config.env
  ↓
Docker Compose
  ├── Vaultwarden
  ├── Cloudflared
  ├── ntfy
  └── Backup SVC
         ↓
      SQLite .backup
         ↓
      staging
         ↓
      Restic
         ↓
      Cloudflare R2
```

## Principais pontos de atenção

### Críticos

- **Não existe restore**
  - O backup é criado, mas uma VM nova não recupera os dados automaticamente.
  - Essa é a principal quebra da promessa de disaster recovery.

- **Configuração desaparece após reboot**
  - `config.env` fica em `/run`, que é temporário.
  - Containers existentes podem reiniciar, mas Compose, `doctor` e recriações podem falhar.

- **Falso sucesso do backup**
  - Se todos os destinos Restic estiverem desabilitados, o job pode notificar sucesso sem enviar backup algum.

### Segurança e integridade

- Backups manuais e agendados podem rodar simultaneamente.
- Qualquer falha de acesso ao Restic pode provocar tentativa indevida de `restic init`.
- O instalador executa conteúdo mutável do branch `master`.
- `genesis.age` permanece na VM depois de utilizado.
- Imagens estão versionadas, mas não fixadas por digest.
- Placeholders e configurações inválidas não são rejeitados antecipadamente.

### Operação

- `depends_on` não garante que Vaultwarden esteja saudável.
- `doctor` verifica containers “running”, não saúde real.
- A verificação de disco não possui limite mínimo.
- O teste atual valida trechos de código, não o comportamento.
- Documentação alterna entre `/` e `/install`.
- Instalação interrompida deixa diretório que impede nova tentativa.

## Pipeline recomendado

```text
Release versionada + checksum
  ↓
Instalação retomável
  ↓
Validação da configuração
  ├── sem placeholders
  ├── Admin Token Argon2
  ├── horários válidos
  └── ≥ 1 destino Restic habilitado
  ↓
Bootstrap do host
  ↓
systemd materializa config.env a cada boot
  ↓
Escolha operacional
  ├── instalação nova → volume vazio
  └── recuperação → vacum restore
                     ├── selecionar snapshot
                     ├── restaurar em staging
                     ├── PRAGMA integrity_check
                     ├── validar arquivos
                     └── popular volume
  ↓
Docker Compose
  ↓
Healthchecks
  ↓
Backup com lock
  ├── SQLite consistente
  ├── Restic
  ├── retenção
  └── validação do snapshot
  ↓
Monitoramento por idade do último backup
```

## Sugestões por prioridade

### 1. Entregar recuperação real

Implementar:

```text
vacum restore [nó] [latest|snapshot]
```

Lógica:

1. Recusar volume não vazio.
2. Parar o Vaultwarden.
3. Restaurar para staging.
4. Validar SQLite.
5. Verificar anexos e chaves.
6. Copiar para o volume.
7. Iniciar serviços.
8. Confirmar login e integridade.

**Por quê:** backup sem restauração testada é apenas uma hipótese de recuperação.

### 2. Corrigir o job de backup

- Falhar quando não houver destino habilitado.
- Adicionar lock global.
- Não executar `restic init` para qualquer erro.
- Separar falha de backup de falha de notificação.

**Por quê:** o resultado do job precisa representar o estado real do snapshot.

### 3. Sobreviver corretamente ao reboot

Adicionar uma unidade systemd pequena:

```text
boot
  ↓
descriptografar config.age
  ↓
escrever /run/vaultwarden/config.env com modo 600
  ↓
iniciar/recriar stack
```

**Por quê:** `/run` é temporário por definição.

### 4. Melhorar diagnóstico

O `doctor` deveria verificar:

- Serviços esperados individualmente.
- Healthcheck do Vaultwarden.
- Espaço mínimo disponível.
- Idade máxima do snapshot.
- Acesso ao Restic.
- Configuração runtime protegida.
- Alterações rastreadas e não rastreadas no Git.

**Por quê:** container em execução não significa aplicação funcional.

### 5. Endurecer distribuição

- Criar releases.
- Fixar uma versão no loader.
- Verificar SHA-256 antes de executar.
- Fixar imagens por digest.
- Tornar `/install` o endpoint oficial.

**Por quê:** executar `master` diretamente torna instalações futuras não reproduzíveis.

## Melhorias opcionais

```text
Depois do restore funcionar
├── Segundo destino Restic
├── Snapshot de volume do provedor
├── Restore mensal automatizado
├── Medição real de RTO/RPO
├── Alertas por backup envelhecido
└── Procedimento testado de upgrade/rollback
```

Não recomendo agora:

- Kubernetes
- Terraform
- Ansible
- PostgreSQL externo
- Segundo Vaultwarden
- Plataforma própria de monitoramento

A lógica é evitar novos componentes antes de fechar o ciclo essencial:

```text
instalar → operar → copiar → restaurar → validar
```

## Ordem prática

```text
P0
├── Corrigir falso sucesso
├── Adicionar lock
└── Implementar restore

P1
├── Regenerar config no boot
├── Validar configuração
├── Adicionar healthchecks
└── Testar VM limpa

P2
├── Melhorar doctor
├── Versionar distribuição
├── Fixar digests
└── Automatizar teste periódico

P3
├── Segundo destino
└── Snapshot do provedor
```

## Conclusão

A base é boa e não precisa de uma arquitetura maior. O caminho correto é completar a lógica existente:

```text
Hoje:     instalação → execução → backup
Necessário: instalação → execução → backup → restore → validação
```

O investimento principal deve ser em **restauração testada, reboot previsível e backup sem falso positivo**.