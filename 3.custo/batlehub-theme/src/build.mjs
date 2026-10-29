#!/usr/bin/env node
// Builds dist/ from theme.config.mjs. Zero dependencies.
//   node src/build.mjs          build (fails if a contrast floor is broken)
//   node src/build.mjs --check  contrast report only, nothing written
import { cp, mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { existsSync, readFileSync } from "node:fs";
import { basename, dirname, join, relative } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { contrast, hex, parseOklch } from "./color.mjs";
import { variables } from "./variables.mjs";
import { renderHome } from "./home.mjs";
import { renderErrors, VARIANTS } from "./errors.mjs";
import { renderAuthentikCss, renderBackground, renderBrandYaml } from "./authentik.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const { default: cfg } = await import(pathToFileURL(join(root, "theme.config.mjs")).href + `?t=${Date.now()}`);
const RENDITIONS = ["dark", "light"];
const name = cfg.name;
if (!/^[a-z0-9-]+$/.test(name)) throw new Error(`name must be lowercase letters, digits and dashes: ${name}`);

const tokens = Object.fromEntries(
  RENDITIONS.map((r) => [r, Object.fromEntries(Object.entries(cfg.tokens[r]).map(([k, v]) => [k, parseOklch(v)]))]),
);

// ── Contrast floors ─────────────────────────────────────────────────────────
let broken = 0;
console.log("contrast".padEnd(28) + RENDITIONS.map((r) => r.padStart(9)).join("") + "    floor");
for (const [fg, bg, floor] of cfg.contrast) {
  const cells = RENDITIONS.map((r) => {
    for (const k of [fg, bg]) if (!tokens[r][k]) throw new Error(`contrast: unknown token "${k}"`);
    const ratio = contrast(tokens[r][fg], tokens[r][bg]);
    const ok = ratio >= floor;
    if (!ok) broken++;
    return ((ok ? "" : "✗ ") + ratio.toFixed(2)).padStart(9);
  });
  console.log(`${fg} / ${bg}`.padEnd(28) + cells.join("") + `    ${floor}`);
}
if (broken) {
  console.error(`\n${broken} pair(s) below their floor. Adjust the tokens or the floors in theme.config.mjs.`);
  process.exit(1);
}
if (process.argv.includes("--check")) process.exit(0);

// ── CSS ─────────────────────────────────────────────────────────────────────
const assets = `/assets`;
const faces = (src) => Object.values(cfg.fonts)
  .flatMap((face) =>
    face.files.map(
      (f) => `@font-face {
  font-family: "${face.family}";
  src: url("${src(f.file)}") format("woff2");
  font-weight: ${f.weight};
  font-display: swap;
}`,
    ),
  )
  .join("\n");
const fontFaces = faces((file) => `${assets}/fonts/${name}/${file}`);

const homeCss = await readFile(join(root, "src/home.css"), "utf8");
const rules = (await readFile(join(root, "src/rules.css"), "utf8") + "\n" + homeCss).replaceAll("__NAME__", name);
const logoFor = { dark: "logo-cream.svg", light: "logo-ink.svg" };
const perRendition = (r) => {
  const p = cfg.plate[r];
  const ink = "--bh-" + p.ink.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase()).replace("ground-", "");
  return `
/* ── Rendition-specific: the plate's ink, and the navbar logo file ──────── */
.bh-plate { opacity: ${p.opacity}; }
@supports ((mask-image: url("x.png")) or (-webkit-mask-image: url("x.png"))) {
  .bh-plate { background: var(${ink}); }
}
@media (max-width: 900px) { .bh-plate { opacity: ${p.opacityNarrow}; } }
#navbar-logo img,
#navbar .navbar-left > .item img[src$="/assets/img/logo.svg"] {
  content: url("${assets}/img/${name}/${logoFor[r]}");
}
`;
};

const css = {};
for (const r of RENDITIONS) {
  const vars = variables(r, tokens[r], cfg.fonts).map(([k, v]) => `  ${k}: ${v};`).join("\n");
  css[r] = `/* ${name} theme for Forgejo — ${r} rendition. Generated; edit theme.config.mjs or src/ and rebuild. */
@import "./theme-${cfg.base}-${r}.css";

:root {
${vars}
}

${fontFaces}

${rules}${perRendition(r)}`;
}
css.auto = `/* ${name} theme for Forgejo — follows the device. Generated. */
@import "./theme-${name}-light.css" (prefers-color-scheme: light);
@import "./theme-${name}-dark.css" (prefers-color-scheme: dark);
`;

// ── Write dist/ ─────────────────────────────────────────────────────────────
await rm(dist, { recursive: true, force: true });
const pub = join(dist, "public/assets");
await mkdir(join(pub, "css"), { recursive: true });
for (const [r, text] of Object.entries(css)) await writeFile(join(pub, "css", `theme-${name}-${r}.css`), text);

await cp(join(root, "assets/fonts"), join(pub, "fonts", name), { recursive: true });
for (const entry of await readdir(join(root, "assets/img"), { withFileTypes: true })) {
  const src = join(root, "assets/img", entry.name);
  // assets/img/theme/* is namespaced; anything else replaces Forgejo's own file of that name.
  if (entry.isDirectory() && entry.name === "theme") await cp(src, join(pub, "img", name), { recursive: true });
  else await cp(src, join(pub, "img", entry.name), { recursive: true });
}
for (const face of Object.values(cfg.fonts))
  for (const f of face.files)
    if (!existsSync(join(pub, "fonts", name, f.file))) throw new Error(`Missing font file assets/fonts/${f.file}`);

if (cfg.home) {
  await mkdir(join(dist, "templates"), { recursive: true });
  await writeFile(join(dist, "templates/home.tmpl"), renderHome(cfg.home));
}

// ── Error pages (error-pages template, served off-Forgejo: inlines everything) ─
let errorsHtml = null; // variant -> template
if (cfg.errors) {
  const fontData = (file) => `data:font/woff2;base64,${readFileSync(join(root, "assets/fonts", file)).toString("base64")}`;
  const bhVars = (r) => variables(r, tokens[r], cfg.fonts).filter(([k]) => k.startsWith("--bh-")).map(([k, v]) => `  ${k}: ${v};`).join("\n");
  const css = `${faces(fontData)}
:root {
${bhVars("light")}
  --fonts-regular: "${cfg.fonts.text.family}", ${cfg.fonts.text.fallback};
  color-scheme: light dark;
}
@media (prefers-color-scheme: dark) {
:root {
${bhVars("dark")}
}
}
${homeCss}
${await readFile(join(root, "src/errors.css"), "utf8")}`;
  const logo = await readFile(join(root, "assets/img/theme/logo-ink.svg"), "utf8");
  errorsHtml = {};
  await mkdir(join(dist, "errors"));
  for (const variant of VARIANTS) {
    errorsHtml[variant] = renderErrors(cfg.errors, { css, logo }, { variant });
    await writeFile(join(dist, `errors-${variant}.html`), errorsHtml[variant]);
    for (const code of [...Object.keys(cfg.errors.pages), "599"])
      await writeFile(join(dist, "errors", `${variant}-${code}.html`), renderErrors(cfg.errors, { css, logo }, { variant, preview: Number(code) }));
  }
}

// ── Authentik (brand CSS + the files it serves + brand/flow settings) ──────────
let authentikOut = null; // { files: dir, brand: dir } under dist/authentik
if (cfg.authentik) {
  const out = join(dist, "authentik");
  const files = join(out, "files");
  const assetsUrl = cfg.deploy.authentikAssets;
  await mkdir(join(out, "brand"), { recursive: true });
  await cp(join(root, "assets/fonts"), join(files, "fonts"), { recursive: true });
  // %(theme)s -> light / dark: the ink logo on the light ground, the cream one on the dark.
  await cp(join(root, "assets/img/theme/logo-ink.svg"), join(files, "logo-light.svg"));
  await cp(join(root, "assets/img/theme/logo-cream.svg"), join(files, "logo-dark.svg"));
  await cp(join(root, "assets/img/favicon.svg"), join(files, "favicon.svg"));
  const platePng = readFileSync(join(root, "assets/img/theme/halftone-plate.png"));
  for (const r of RENDITIONS) {
    const p = cfg.plate[r];
    await writeFile(
      join(files, `background-${r}.svg`),
      renderBackground({ ground: hex(tokens[r].ground), ink: hex(tokens[r][cfg.authentik.plateInk?.[r] ?? p.ink]), opacity: p.opacity }, platePng),
    );
  }
  const layout = cfg.authentik.layout;
  const flows = Object.fromEntries(Object.entries(cfg.authentik.flows || {}).map(([slug, f]) => [slug, { layout, ...f }]));
  await writeFile(join(out, "brand", "custom.css"), renderAuthentikCss({ tokens, fonts: cfg.fonts, assets: assetsUrl }));
  await writeFile(join(out, "brand", "brand.yaml"), renderBrandYaml({ ...cfg.authentik, flows }, assetsUrl));
  authentikOut = { files, brand: join(out, "brand") };
}

// ── Deploy manifests ────────────────────────────────────────────────────────
async function walk(dir) {
  const out = [];
  for (const e of await readdir(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...(await walk(p)));
    else out.push(p);
  }
  return out.sort();
}
const files = [...(await walk(join(dist, "public"))), ...(cfg.home ? await walk(join(dist, "templates")) : [])].map((f) =>
  relative(dist, f).split("\\").join("/"),
);
const keys = new Map();
for (const f of files) {
  const key = basename(f);
  if (keys.has(key)) throw new Error(`ConfigMap key collision: ${f} and ${keys.get(key)} share the name ${key}`);
  keys.set(key, f);
}
const d = cfg.deploy;
const themes = [...d.keepThemes, ...["auto", "light", "dark"].map((r) => `${name}-${r}`)];
await writeFile(
  join(dist, "kustomization.yaml"),
  `# Generated. Apply with kustomize (or as an ArgoCD source) next to the Forgejo chart.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${d.namespace}
configMapGenerator:
  - name: ${d.configMapName}
    options:
      disableNameSuffixHash: true
    files:
${files.map((f) => `      - ${f}`).join("\n")}
`,
);
const mounts = [["public", "public"], ...(cfg.home ? [["templates", "templates"]] : [])];
await writeFile(
  join(dist, "values.forgejo.yaml"),
  `# Generated. Merge into the Forgejo Helm chart values.
gitea:
  config:
    ui:
      THEMES: ${themes.join(",")}
      DEFAULT_THEME: ${d.defaultTheme}

extraVolumes:
  - name: theme-${name}
    configMap:
      name: ${d.configMapName}
      items:
${[...keys].map(([key, f]) => `        - { key: ${key}, path: ${f} }`).join("\n")}

extraContainerVolumeMounts:
${mounts.map(([sub, to]) => `  - { name: theme-${name}, mountPath: ${d.customPath}/${to}, subPath: ${sub}, readOnly: true }`).join("\n")}
`,
);

// ── Chart copy ──────────────────────────────────────────────────────────────
// The same files, for a Helm chart that reads them with .Files.Glob. Replaced
// wholesale so a file dropped from assets/ also leaves the chart.
if (d.chartDir) {
  const chart = join(root, d.chartDir);
  await rm(chart, { recursive: true, force: true });
  for (const [sub] of mounts) await cp(join(dist, sub), join(chart, sub), { recursive: true });
  await writeFile(
    join(chart, "theme.yaml"),
    `# Generated by 3.custo/batlehub-theme (npm run build). Do not edit.
name: ${name}
themes: ${themes.join(",")}
defaultTheme: ${d.defaultTheme}
`,
  );
}
if (errorsHtml && d.errorsDir) {
  const dir = join(root, d.errorsDir);
  await rm(dir, { recursive: true, force: true });
  await mkdir(dir, { recursive: true });
  for (const [variant, html] of Object.entries(errorsHtml)) await writeFile(join(dir, `errors-${variant}.html`), html);
}
if (authentikOut) {
  for (const [src, to] of [[authentikOut.files, d.authentikFilesDir], [authentikOut.brand, d.authentikBrandDir]]) {
    if (!to) continue;
    await rm(join(root, to), { recursive: true, force: true });
    await cp(src, join(root, to), { recursive: true });
  }
}

// ── Preview (no Forgejo needed) ─────────────────────────────────────────────
const local = (text) => text.replace(/@import[^;]+;\n/g, "").replaceAll('"/assets/', '"./public/assets/');
const swatch = (r) =>
  Object.entries(tokens[r])
    .map(([k, c]) => {
      const onGround = k === "ground" ? "" : ` · ${contrast(c, tokens[r].ground).toFixed(2)}:1`;
      return `<div class="pv-sw"><i style="background:${hex(c)}"></i><b>${k}</b><span>${hex(c)}${onGround}</span></div>`;
    })
    .join("");
if (cfg.home || true) {
  const home = cfg.home ? renderHome(cfg.home, { preview: true }) : "";
  await writeFile(
    join(dist, "preview.html"),
    `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${name} — theme preview</title>
<style id="pv-dark">${local(css.dark)}</style>
<style id="pv-light" disabled>${local(css.light)}</style>
<style>
  body { margin: 0; background: var(--color-body); color: var(--color-text); font-family: var(--fonts-proportional); font-size: 14px; }
  .pv-bar { display: flex; gap: 12px; align-items: center; padding: 8px 24px; background: var(--color-nav-bg); border-bottom: 1px solid var(--bh-rule-soft); font-size: 12px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--bh-ink-dim); }
  .pv-bar img { height: 30px; }
  .pv-bar button, .pv-btn { font: inherit; letter-spacing: inherit; text-transform: inherit; color: var(--bh-ink-dim); background: transparent; border: 1px solid var(--bh-rule-strong); padding: 8px 12px; cursor: pointer; }
  .pv-bar button { margin-left: auto; }
  .ui.primary.button { display: inline-block; background: var(--color-primary); color: var(--color-primary-contrast); border: 0; text-decoration: none; cursor: pointer; }
  .pv-block { padding: 24px; border-top: 1px solid var(--bh-rule-soft); display: flex; flex-wrap: wrap; gap: 12px 24px; align-items: center; }
  .pv-sw { display: grid; grid-template-columns: 40px auto; column-gap: 12px; width: 232px; font-size: 12px; }
  .pv-sw i { grid-row: span 2; height: 40px; border: 1px solid var(--bh-rule-strong); }
  .pv-sw span { color: var(--bh-ink-dim); }
  .pv-diff { font-size: 13px; width: 100%; max-width: 640px; border: 1px solid var(--bh-rule-soft); }
  .pv-diff div { padding: 2px 12px; }
  a { color: var(--color-primary); }
</style></head>
<body>
<div class="pv-bar"><img id="pv-logo" src="./public/assets/img/${name}/logo-cream.svg" alt=""> <span>Explore</span><span>Help</span>
  <button type="button" id="pv-toggle">Switch to light</button></div>
${home}
<div class="pv-block" id="pv-swatches"></div>
<div class="pv-block">
  <button class="ui primary button" type="button">Primary action</button>
  <button class="pv-btn" type="button">Control</button>
  <a href="#">A link</a>
  <span style="color:var(--color-green)">passed</span><span style="color:var(--color-orange)">waiting</span><span style="color:var(--color-red)">refused</span>
  <div class="pv-diff">
    <div style="background:var(--color-diff-removed-row-bg)">- removed line, with a <span style="background:var(--color-diff-removed-word-bg)">changed word</span></div>
    <div style="background:var(--color-diff-added-row-bg)">+ added line, with a <span style="background:var(--color-diff-added-word-bg)">changed word</span></div>
  </div>
</div>
<script>
  const sw = { dark: ${JSON.stringify(swatch("dark"))}, light: ${JSON.stringify(swatch("light"))} };
  let mode = "dark";
  const apply = () => {
    document.getElementById("pv-dark").disabled = mode !== "dark";
    document.getElementById("pv-light").disabled = mode !== "light";
    document.getElementById("pv-swatches").innerHTML = sw[mode];
    document.getElementById("pv-logo").src = "./public/assets/img/${name}/" + (mode === "dark" ? "logo-cream.svg" : "logo-ink.svg");
    document.getElementById("pv-toggle").textContent = "Switch to " + (mode === "dark" ? "light" : "dark");
  };
  document.getElementById("pv-toggle").addEventListener("click", () => { mode = mode === "dark" ? "light" : "dark"; apply(); });
  apply();
</script>
</body></html>
`,
  );
}

console.log(`\nbuilt dist/${d.chartDir ? ` and ${d.chartDir}` : ""}${errorsHtml && d.errorsDir ? ` and ${d.errorsDir}` : ""}${authentikOut ? ` and ${[d.authentikFilesDir, d.authentikBrandDir].filter(Boolean).join(", ")}` : ""} — ${files.length} files, themes: ${["auto", "light", "dark"].map((r) => `${name}-${r}`).join(", ")}`);
