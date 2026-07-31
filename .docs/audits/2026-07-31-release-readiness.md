# Auditoria de prontidão da primeira release — 2026-07-31

## Evidências aprovadas

- Testes locais de sintaxe e comportamento passaram, incluindo Genesis + `secrets.age` sem arquivo de senha, Git retry, restore por nome, backup e Worker.
- Teste 001 em contêiner Ubuntu/systemd aprovou bootstrap e reboot.
- Teste 002 na Oracle aprovou instalação, Tunnel, backup remoto, reboot, `vacum check` e `vacum doctor`.
- Teste 003 destruiu o volume e restaurou snapshots remotos por `r2 latest`.
- A rodada final recuperou 1 usuário, 10 itens, 3 pastas e 1 anexo real com hashes SQLite/anexo/RSA idênticos; login e download foram confirmados pelo operador.
- RTO final observado: 42 segundos; idade do snapshot no início: 37 segundos.
- `vacum.brazill.org` e `ntfy.brazill.org` responderam HTTP 200 com uma réplica VACUM na Oracle.

## Estrutura auditada

```text
.source/
├── _env/
│   ├── _sample/       # público
│   ├── _secrets/      # plaintext local ignorado
│   ├── genesis.age    # cifrado/versionável
│   └── secrets.age    # cifrado/versionável
├── _main/
│   ├── .bin/
│   ├── .cloudflare/
│   └── .web/
├── _test/
│   └── README.md      # somente contrato público
└── _vacum/            # bootstrap, CLI, backup e restore
```

As regras Git foram verificadas: `_env/_secrets/` e artefatos internos de `_test/` são ignorados; `_sample/`, `genesis.age`, `secrets.age` e `_test/README.md` são versionáveis.

## Correções desta auditoria

- caminhos canônicos migrados de `_secrets/secrets.age` para `_env/secrets.age`;
- exemplos públicos migrados para `_env/_sample/`;
- Worker migrado de `_main/.worker/` para `_main/.cloudflare/`;
- `vacum config` passou a criar Genesis e pacote cifrado antes da instalação;
- Genesis usa senha no prompt nativo do `age`, sem eco nem persistência;
- teste comportamental cobre criação, descriptografia e conteúdo do pacote;
- documentação de release consolidada em `planning/release.md`.

## Bloqueios atuais

1. `genesis.age` e `secrets.age` finais foram gerados em modo `600` na nova estrutura; a correspondência entre ambos será provada pela instalação final, pois a senha não é entregue ao agente.
2. Credenciais expostas continuam com rotação deliberadamente adiada; a rotação é obrigatória antes da tag.
3. O loader ainda baixa `master` diretamente e não verifica checksum. A primeira tag pode registrar o estado aprovado, mas distribuição reproduzível exige fixar a tag/release no loader e validar SHA-256 antes da execução.
4. A VM Oracle está limpa e aguarda a instalação final a partir do commit candidato; nenhuma tag de produção existe ainda.

## Decisão

**NO-GO para criar a tag agora.** O código e o disaster recovery estão comprovados, mas os quatro bloqueios acima precisam ser fechados pela pipeline de `planning/release.md`. Não criar commit vazio nem tag antecipada.
