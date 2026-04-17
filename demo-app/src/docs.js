function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function renderOperation(path, method, operation) {
  const tag = operation.tags && operation.tags.length > 0 ? operation.tags[0] : "General";
  const auth = operation.security ? "Requires bearer auth" : "No auth";

  return `
    <article class="operation">
      <div class="operation-header">
        <span class="method method-${method}">${method.toUpperCase()}</span>
        <code>${escapeHtml(path)}</code>
      </div>
      <p class="summary">${escapeHtml(operation.summary || "No summary provided.")}</p>
      <div class="meta">
        <span>${escapeHtml(tag)}</span>
        <span>${escapeHtml(auth)}</span>
      </div>
    </article>
  `;
}

function renderDocsPage(spec) {
  const operations = Object.entries(spec.paths)
    .flatMap(([path, methods]) =>
      Object.entries(methods).map(([method, operation]) =>
        renderOperation(path, method, operation)
      )
    )
    .join("\n");

  const specJson = escapeHtml(JSON.stringify(spec, null, 2));

  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(spec.info.title)} Docs</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #f3efe5;
        --panel: #fffdf8;
        --ink: #1d1b16;
        --muted: #6d6659;
        --line: #ddd2bc;
        --accent: #0d5c63;
        --get: #1b7f3b;
        --post: #005f99;
        --put: #9a4d00;
        --delete: #a32020;
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        font-family: Georgia, "Times New Roman", serif;
        color: var(--ink);
        background:
          radial-gradient(circle at top left, rgba(13, 92, 99, 0.12), transparent 32%),
          linear-gradient(180deg, #f7f1e5 0%, var(--bg) 100%);
      }

      main {
        max-width: 1080px;
        margin: 0 auto;
        padding: 32px 20px 48px;
      }

      .hero,
      .panel {
        background: rgba(255, 253, 248, 0.92);
        border: 1px solid var(--line);
        border-radius: 20px;
        box-shadow: 0 18px 50px rgba(40, 33, 20, 0.08);
      }

      .hero {
        padding: 28px;
      }

      h1,
      h2 {
        margin: 0 0 12px;
      }

      p {
        margin: 0;
        line-height: 1.6;
      }

      .hero p + p,
      .panel p + p {
        margin-top: 12px;
      }

      .actions {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        margin-top: 20px;
      }

      .button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        padding: 10px 14px;
        border-radius: 999px;
        border: 1px solid var(--accent);
        color: var(--accent);
        text-decoration: none;
        font-weight: 600;
      }

      .grid {
        display: grid;
        gap: 20px;
        margin-top: 20px;
      }

      .panel {
        padding: 24px;
      }

      .operations {
        display: grid;
        gap: 14px;
        margin-top: 18px;
      }

      .operation {
        padding: 16px;
        border: 1px solid var(--line);
        border-radius: 16px;
        background: rgba(255, 255, 255, 0.72);
      }

      .operation-header {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        align-items: center;
      }

      .method {
        min-width: 74px;
        text-align: center;
        padding: 6px 10px;
        border-radius: 999px;
        color: white;
        font-size: 0.82rem;
        font-weight: 700;
        letter-spacing: 0.04em;
      }

      .method-get { background: var(--get); }
      .method-post { background: var(--post); }
      .method-put { background: var(--put); }
      .method-delete { background: var(--delete); }

      .summary {
        margin-top: 10px;
      }

      .meta {
        display: flex;
        gap: 10px;
        flex-wrap: wrap;
        margin-top: 12px;
        color: var(--muted);
        font-size: 0.95rem;
      }

      pre {
        margin: 18px 0 0;
        padding: 18px;
        overflow: auto;
        border-radius: 14px;
        border: 1px solid var(--line);
        background: #1f2430;
        color: #f8f8f2;
      }

      @media (max-width: 640px) {
        main {
          padding: 20px 14px 32px;
        }

        .hero,
        .panel {
          padding: 18px;
          border-radius: 16px;
        }
      }
    </style>
  </head>
  <body>
    <main>
      <section class="hero">
        <h1>${escapeHtml(spec.info.title)}</h1>
        <p>${escapeHtml(spec.info.description)}</p>
        <p>OpenAPI version ${escapeHtml(spec.openapi)}. This lightweight page keeps the spec available without pulling in extra npm packages that were tripping the Socket report.</p>
        <div class="actions">
          <a class="button" href="/v3/api-docs">View raw OpenAPI JSON</a>
        </div>
      </section>

      <section class="grid">
        <section class="panel">
          <h2>Endpoints</h2>
          <div class="operations">${operations}</div>
        </section>

        <section class="panel">
          <h2>Spec Snapshot</h2>
          <p>The full JSON is still served at <code>/v3/api-docs</code> for scanners and tooling.</p>
          <pre>${specJson}</pre>
        </section>
      </section>
    </main>
  </body>
</html>`;
}

module.exports = {
  renderDocsPage,
};
