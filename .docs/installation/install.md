# Wizard de instalação

O loader público é `.source/_main/.bin/vacum`; o wizard canônico é `.source/_vacum/.cmd/install.sh`. Ele valida Ubuntu, instala Git quando ausente, clona o repositório em `/opt/vacum-src`, recebe `genesis.age` por caminho ou colagem e chama o bootstrap. Recusa sobrescrever um diretório existente.

## Comando curto no domínio raiz

O Cloudflare Worker `.source/_main/.cloudflare/index.js` serve a página em `.source/_main/.web/index.html` para navegadores e o loader `.source/_main/.bin/vacum` para curl/wget. Configure a variável `URL` e o domínio `vacum.brazill.org` no Worker.

```bash
curl -fsSL https://vacum.brazill.org/ | sh
```

## Correção do endpoint canônico

O Worker atual atende `/install`; use:

```bash
curl -fsSL https://vacum.brazill.org/install | sh
```

O comando anterior na raiz é histórico e retorna `404` enquanto a raiz não for explicitamente habilitada.

## Menu de configuração

Depois de recuperar `secrets.age`, o instalador oferece abrir `VACUM // CONFIG` antes de iniciar os serviços. O menu permite configurar Git, adicionar ou remover `restic/[nome].env`, editar retenção/agenda/limite do backup e configurar ntfy. Credenciais são lidas sem eco, arquivos são substituídos atomicamente e o pacote é selado ao salvar. Falha temporária no push não impede a instalação; o timer tentará novamente.
