# Wizard de instalação

O loader público é `vacum` na raiz; o wizard canônico é `.source/.base/.vacum/.cmd/install.sh`. Ele valida Ubuntu, instala Git quando ausente, clona o repositório em `/opt/vacum-src`, recebe `genesis.age` por caminho ou colagem e chama o bootstrap. Recusa sobrescrever um diretório existente.

## Comando curto no domínio raiz

GitHub Pages é estático: não pode servir HTML ao navegador e shell ao `curl` na mesma URL. Publique `.source/.base/_release/.worker/index.js` como Cloudflare Worker na rota `vaultx.brazill.org/*`. O Worker envia `/` para o loader `vacum` somente quando o `User-Agent` é curl/wget; navegadores recebem o Pages normalmente.

```bash
curl -fsSL https://vaultx.brazill.org/ | sh
```
