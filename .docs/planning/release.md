# Primeira release de produção

## Objetivo

Promover um commit e um snapshot Restic que tenham sido validados juntos. A release é o ponto de saúde do código; o snapshot associado é o ponto de restauração dos dados.

```text
release/tag imutável
├── commit testado
├── .source/_env/genesis.age
├── .source/_env/secrets.age
├── snapshot Restic nomeado
├── check + doctor
├── backup + restore destrutivo
└── RTO/RPO observados
```

`genesis.age` e `secrets.age` são cifrados e versionáveis. `.source/_env/_secrets/`, `genesis.png`, senhas e todo conteúdo interno de `_test/` permanecem locais e ignorados; somente `_env/_sample/` e `_test/README.md` são públicos.

## Pipeline final

### 1. Preparar ambiente cifrado

1. Copiar `_env/_sample/` para `_env/_secrets/` e preencher os valores reais.
2. Executar `vacum config` → **Criar Genesis**.
3. Digitar e confirmar uma senha forte diretamente no prompt `age`; ela não é salva pelo VACUM.
4. Responder `s` para gerar `secrets.age`, ou usar depois **Criar secrets.age**.
5. Guardar `genesis.png` e a senha fora do repositório e fora da VM.
6. Confirmar que somente `genesis.age` e `secrets.age` aparecem como versionáveis.

### 2. Criar commit candidato

```bash
vacum test
git diff --check
git status --short
git add .source .docs
git commit -m 'chore: prepare first production release'
git push origin master
```

O commit candidato ainda não é uma release. Não marcar tag antes da prova em VM limpa.

### 3. Instalar em VM limpa

```bash
curl -fsSL https://vacum.brazill.org/install | sh
```

Usar o `genesis.age` do commit candidato. Confirmar:

- Ubuntu 24.04, Docker/Compose, UFW, fail2ban e unattended-upgrades;
- SSH por chave, sem senha e sem root;
- runtime `700` com arquivos `600`;
- Vaultwarden saudável;
- cloudflared como única borda;
- ntfy e Backup SVC ativos;
- nenhuma porta da aplicação publicada.

### 4. Popular e congelar produção

1. Habilitar cadastro somente durante a criação da primeira conta.
2. Criar conta, importar itens/pastas e adicionar um anexo real.
3. Desabilitar novos cadastros.
4. Rotacionar Git PAT, Tunnel, S3/Restic e ntfy.
5. Executar `vacum sync` para selar e publicar o novo `secrets.age`.
6. Não modificar o cofre durante o backup candidato.

### 5. Criar e provar o restore-point

```bash
sudo vacum backup
sudo vacum status
sudo vacum check
sudo vacum doctor
```

Registrar o ID e horário do snapshot. Em VM/volume descartável vazio, executar `vacum restore r2 latest`, subir o stack e comparar:

- usuário, itens, pastas e anexos;
- SHA-256 do arquivo anexado e das chaves RSA;
- dump lógico e `PRAGMA integrity_check` do SQLite;
- login e abertura/download do anexo;
- domínio HTTP 200;
- reboot, rematerialização dos secrets, `check` e `doctor`.

Medir RTO desde a destruição até Vaultwarden saudável e idade do snapshot no início como RPO observado.

### 6. Promover release

Somente depois de todos os critérios anteriores:

```bash
git tag -a production-AAAA-MM-DD \
  -m 'restore=r2:SNAPSHOT; check=PASS; doctor=PASS; recovery=PASS; RTO=Ns; RPO=Ns'
git push origin production-AAAA-MM-DD
```

Criar um GitHub Release sobre essa tag e repetir na descrição: nó/snapshot, resultados, RTO/RPO e limitações. Tags de produção são imutáveis; uma nova promoção cria outra tag.

## Rollback e recuperação

- **Código:** checkout da tag de produção desejada.
- **Configuração:** materializar o `secrets.age` daquela tag com o Genesis correspondente.
- **Dados:** restaurar o snapshot registrado na mesma tag, nunca escolher outro silenciosamente.
- **Validação:** SQLite, hashes, login, domínio, reboot, `check` e `doctor`.

## Critério GO

Todos devem estar verdadeiros:

- árvore Git limpa e testes aprovados;
- Genesis e pacote cifrado gerados sem senha persistida;
- credenciais finais rotacionadas e com menor privilégio;
- instalação pública em VM limpa;
- quatro serviços e Tunnel saudáveis;
- backup real e restore destrutivo do snapshot candidato;
- conta, itens, pasta, anexo, SQLite e RSA recuperados;
- reboot, `check` e `doctor` aprovados;
- RTO/RPO aceitos;
- tag e release associadas ao snapshot comprovado.

Qualquer falha mantém o estado **NO-GO** e nenhuma tag de produção é criada.
