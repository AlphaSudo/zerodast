function renderDocsPage() {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>ZeroDAST Demo API Docs</title>
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
        white-space: pre-wrap;
        word-break: break-word;
      }

      .loading,
      .error {
        color: var(--muted);
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
        <h1 id="title">ZeroDAST Demo API</h1>
        <p id="description">Loading OpenAPI description...</p>
        <p id="version">OpenAPI spec available at <code>/v3/api-docs</code>.</p>
        <div class="actions">
          <a class="button" href="/v3/api-docs">View raw OpenAPI JSON</a>
        </div>
      </section>

      <section class="grid">
        <section class="panel">
          <h2>Endpoints</h2>
          <div id="operations" class="operations">
            <p class="loading">Loading endpoints...</p>
          </div>
        </section>

        <section class="panel">
          <h2>Spec Snapshot</h2>
          <p>The full JSON is still served at <code>/v3/api-docs</code> for scanners and tooling.</p>
          <pre id="spec-json">Loading spec...</pre>
        </section>
      </section>
    </main>

    <script>
      const methodClassNames = {
        get: "method-get",
        post: "method-post",
        put: "method-put",
        delete: "method-delete",
      };

      function appendTextElement(parent, tagName, className, text) {
        const node = document.createElement(tagName);
        if (className) {
          node.className = className;
        }
        node.textContent = text;
        parent.appendChild(node);
        return node;
      }

      function renderOperation(path, method, operation) {
        const article = document.createElement("article");
        article.className = "operation";

        const header = document.createElement("div");
        header.className = "operation-header";

        const methodTag = document.createElement("span");
        methodTag.className = "method " + (methodClassNames[method] || "method-get");
        methodTag.textContent = method.toUpperCase();
        header.appendChild(methodTag);

        appendTextElement(header, "code", "", path);
        article.appendChild(header);

        appendTextElement(article, "p", "summary", operation.summary || "No summary provided.");

        const meta = document.createElement("div");
        meta.className = "meta";
        const tag = operation.tags && operation.tags.length > 0 ? operation.tags[0] : "General";
        const auth = operation.security ? "Requires bearer auth" : "No auth";
        appendTextElement(meta, "span", "", tag);
        appendTextElement(meta, "span", "", auth);
        article.appendChild(meta);

        return article;
      }

      async function loadDocs() {
        const title = document.getElementById("title");
        const description = document.getElementById("description");
        const version = document.getElementById("version");
        const operations = document.getElementById("operations");
        const specJson = document.getElementById("spec-json");

        try {
          const response = await fetch("/v3/api-docs");
          if (!response.ok) {
            throw new Error("Failed to load spec: " + response.status);
          }

          const spec = await response.json();

          title.textContent = spec.info && spec.info.title ? spec.info.title : "ZeroDAST Demo API";
          description.textContent =
            spec.info && spec.info.description
              ? spec.info.description
              : "OpenAPI description unavailable.";
          version.textContent = "OpenAPI version " + (spec.openapi || "unknown") + ".";
          specJson.textContent = JSON.stringify(spec, null, 2);

          operations.replaceChildren();
          const paths = spec.paths || {};
          Object.entries(paths).forEach(([path, methods]) => {
            Object.entries(methods).forEach(([method, operation]) => {
              operations.appendChild(renderOperation(path, method, operation));
            });
          });

          if (!operations.hasChildNodes()) {
            appendTextElement(operations, "p", "loading", "No endpoints were found in the spec.");
          }
        } catch (error) {
          description.textContent = "Unable to load the OpenAPI description.";
          version.textContent = "The raw spec is still expected at /v3/api-docs.";
          operations.replaceChildren();
          appendTextElement(operations, "p", "error", error.message);
          specJson.textContent = error.message;
        }
      }

      loadDocs();
    </script>
  </body>
</html>`;
}

module.exports = {
  renderDocsPage,
};
