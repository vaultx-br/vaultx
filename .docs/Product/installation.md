# Instalação

## Pré-requisitos

- VM Ubuntu com console do provedor disponível.
- Acesso administrativo por `sudo` ou root.
- Chave SSH já validada; o bootstrap desativa senha e login root.
- `genesis.age` e sua senha sob custódia segura e fora da VM.
- `secrets.age` compatível com esse Genesis no repositório.
- Credenciais finais com menor privilégio para Git, Tunnel, S3 e ntfy.
- Ao menos um destino Restic habilitado.

Nunca cole valores sensíveis em logs, documentação ou tickets.

## Preparação segura

Em uma máquina confiável:

1. Copie os modelos de `.source/_env/_sample/` para `.source/_env/_secrets/`.
2. Preencha localmente os arquivos por consumidor e pelo menos `restic/[nome].env`.
3. Execute `vacum config` e escolha **Criar Genesis**.
4. Digite uma senha forte diretamente no prompt do `age`.
5. Gere `secrets.age` quando solicitado.
6. Guarde o QR e a senha em local offline separado.
7. Confirme que plaintext, QR e artefatos de teste não aparecem no Git.

Arquivos cifrados versionáveis:

```text
.source/_env/genesis.age
.source/_env/secrets.age
```

## Instalação pública

Na VM limpa:

```bash
curl -fsSL https://vacum.brazill.org/install | sh
```

O wizard:

1. confirma `/opt/vacum-src`;
2. clona o repositório;
3. instala o comando `vacum`;
4. solicita o caminho do Genesis ou permite colá-lo;
5. oferece abrir o menu de configuração;
6. executa o bootstrap e inicia os serviços.

O instalador recusa sobrescrever um clone existente. Se uma instalação nova falhar antes de concluir, ele remove o clone e o link criados naquela tentativa.

## Verificação imediata

```bash
sudo vacum check
sudo vacum status
sudo vacum doctor
```

Confirme também:

- Vaultwarden saudável;
- Tunnel conectado e domínio esperado acessível;
- nenhum serviço da aplicação publicado diretamente na VM;
- runtime com diretório `700` e arquivos `600`;
- quatro serviços presentes: `vaultwarden`, `cloudflared`, `ntfy`, `backup-svc`;
- snapshot existente ou primeiro backup manual aprovado.

Para criar o primeiro snapshot real:

```bash
sudo vacum backup
sudo vacum status
sudo vacum doctor
```

## Reboot de aceite

Depois do primeiro backup:

```bash
sudo reboot
```

Após reconectar, repita `check`, `status` e `doctor`. Isso prova que o serviço systemd rematerializou os secrets em `/run`.

## Falhas comuns

- **“Ubuntu necessário”**: use uma VM Ubuntu suportada.
- **destino já existe**: não apague um nó válido; inspecione a instalação anterior.
- **Genesis/secrets incompatíveis**: use o par produzido pela mesma identidade age.
- **placeholder ou nenhum Restic habilitado**: corrija via `vacum config`.
- **Tunnel reiniciando**: valide a credencial e o domínio sem imprimir o token.
- **doctor acusa Git sujo**: revise alterações antes de operar sincronização automática.
