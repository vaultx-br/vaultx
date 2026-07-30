const pages = "https://vaultx-br.github.io/vaultx";
const installer = "https://raw.githubusercontent.com/vaultx-br/vaultx/master/vacum";

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/" && /(?:curl|wget)/i.test(request.headers.get("user-agent") || "")) {
      return fetch(installer, { headers: { Accept: "text/plain" } });
    }
    return fetch(`${pages}${url.pathname}${url.search}`, request);
  },
};
