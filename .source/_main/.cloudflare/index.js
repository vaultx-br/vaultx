const installPath = "/install";

function rawBase(repository) {
  const url = new URL(repository.replace(/\.git$/, ""));
  if (url.hostname === "github.com") {
    return `https://raw.githubusercontent.com${url.pathname}/master`;
  }
  return repository.replace(/\/$/, "");
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== installPath && url.pathname !== `${installPath}/`) {
      return new Response("Not Found", { status: 404 });
    }
    if (!env.URL) return new Response("Worker URL not configured", { status: 500 });
    const shell = /(?:curl|wget)/i.test(request.headers.get("user-agent") || "");
    const base = rawBase(env.URL);
    const entry = shell ? ".source/_main/.bin/vacum" : ".source/_main/.web/index.html";
    const upstream = await fetch(`${base}/${entry}`);
    const headers = new Headers({
      "content-type": shell ? "text/plain; charset=utf-8" : "text/html; charset=utf-8",
      "cache-control": "no-store",
      "vary": "User-Agent",
    });
    return new Response(upstream.body, { status: upstream.status, headers });
  },
};
