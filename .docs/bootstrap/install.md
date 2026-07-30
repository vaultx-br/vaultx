# Wizard de instalação

O loader público é `.source/_main/.bin/vacum`; o wizard canônico é `.source/_vacum/.cmd/install.sh`. Ele valida Ubuntu, instala Git quando ausente, clona o repositório em `/opt/vacum-src`, recebe `genesis.age` por caminho ou colagem e chama o bootstrap. Recusa sobrescrever um diretório existente.

## Comando curto no domínio raiz

O Cloudflare Worker `.source/_main/.worker/index.js` serve a página em `.source/_main/.web/index.html` para navegadores e o loader `.source/_main/.bin/vacum` para curl/wget. Configure a variável `URL` e o domínio `vacum.brazill.org` no Worker.

```bash
curl -fsSL https://vacum.brazill.org/ | sh
```
