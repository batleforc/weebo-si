// Renders the error-pages templates (github.com/tarampampam/error-pages, a Go text/template)
// from the `errors` config block. The pages are served on hosts that are not Forgejo, so
// everything they need (tokens, fonts, sprites) is inlined: they load nothing. The scenes
// themselves are in scenes.mjs.

import { SCENES } from "./scenes.mjs";

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

export const VARIANTS = ["internal", "external"];

// Any code without its own page: error-pages' own message and description.
const FALLBACK = {
  label: "Error {{ .StatusCode }}",
  title: "{{ .Message | escape }}",
  caption: "{{ .Description | escape }}",
};

// ── Sprites ─────────────────────────────────────────────────────────────────
const rects = (svg) => [...svg.matchAll(/M(\d+) (\d+)h(\d+)v1h-\d+z/g)].map(([, x, y, w]) => ({ x: +x, y: +y, w: +w }));
const d = (rs) => rs.map((r) => `M${r.x} ${r.y}h${r.w}v1h-${r.w}z`).join("");
const COLOURS = { "#": "c-ink", "*": "c-copper", "+": "c-accent", "-": "c-dim", o: "c-raised" };
// Sprite pixels from the stage's left edge (past the page gutter) and floor.
const place = (x, y) => `left:calc(var(--u)*${6 + x});bottom:calc(var(--u)*${y})`;

/** The crab, from the logo's rows 0-12, cut into the parts the scenes move. */
function crab(logo) {
  const all = rects(logo).filter((r) => r.y <= 12);
  if (!all.length) throw new Error("errors: no pixel rects found in the logo SVG");
  const part = (cls, keep) => `<path class="cr-part ${cls}" d="${d(all.filter(keep))}"/>`;
  const head = (r) => r.y <= 5;
  return `<svg class="bh-crab-svg" viewBox="0 0 26 13"><g class="cr-crab">${[
    part("cr-claw-l", (r) => head(r) && r.x < 9),
    part("cr-claw-r", (r) => head(r) && r.x >= 17),
    part("cr-eyes", (r) => head(r) && r.x >= 9 && r.x < 17),
    part("cr-body", (r) => r.y >= 6 && r.y <= 11),
    part("cr-legs-a", (r) => r.y === 12 && (r.x === 5 || r.x === 17)),
    part("cr-legs-b", (r) => r.y === 12 && r.x !== 5 && r.x !== 17),
  ].join("")}</g></svg>`;
}

/** The logo's shelf (rows 13-40) as sprite art; `books: false` keeps the frame only. */
function shelf(logo, books) {
  const grid = Array.from({ length: 28 }, () => Array(26).fill("."));
  // Pixel by pixel: the logo merges the right post with a book in some rows.
  const frame = (r, x) => r.w === 26 || x < 2 || x >= 24;
  const book = (r) => r.x >= 13 && r.x <= 15 && r.y >= 18 && r.y <= 25;
  for (const r of rects(logo).filter((r) => r.y >= 13))
    for (let x = r.x; x < r.x + r.w; x++) if (books || frame(r, x)) grid[r.y - 13][x] = book(r) ? "k" : "#";
  return grid.map((row) => row.join(""));
}

function sprite({ cls, x, y, art, parts = {}, still }, logo) {
  if (art === "shelf" || art === "shelf-empty") [art, parts] = [shelf(logo, art === "shelf"), { k: "c-ink sh-book" }];
  const w = Math.max(...art.map((l) => l.length));
  const byClass = new Map();
  art.forEach((line, row) => {
    for (const m of line.matchAll(/([^.])\1*/g)) {
      const c = COLOURS[m[1]] ?? parts[m[1]];
      if (!c) throw new Error(`errors: sprite ${cls}: no colour for "${m[1]}"`);
      byClass.set(c, (byClass.get(c) ?? "") + `M${m.index} ${row}h${m[0].length}v1h-${m[0].length}z`);
    }
  });
  const paths = [...byClass].map(([c, path]) => `<path class="${c}" d="${path}"/>`).join("");
  return `<svg class="bh-prop ${cls}${still ? " rm-show" : ""}" viewBox="0 0 ${w} ${art.length}" style="${place(x, y)};width:calc(var(--u)*${w});height:calc(var(--u)*${art.length})">${paths}</svg>`;
}

/**
 * `css` is the page's complete stylesheet, `logo` the pixel logo SVG (one path of 1px-high
 * rects). `variant` is "internal" (lists `errors.internal.links`) or "external" (page head
 * only). With `preview` set to a status code, returns plain HTML for that code.
 */
export function renderErrors(errors, { css, logo }, { variant, preview } = {}) {
  if (!VARIANTS.includes(variant)) throw new Error(`errors: unknown variant "${variant}"`);
  const pages = Object.entries(errors.pages).map(([code, p]) => [Number(code), {
    label: esc(p.label),
    title: esc(p.title),
    caption: esc(p.caption),
    scene: p.scene,
  }]);
  const fallback = { ...FALLBACK, scene: errors.scene };
  for (const s of [...pages.map(([, p]) => p.scene), fallback.scene])
    if (!SCENES[s]) throw new Error(`errors: unknown scene "${s}" (one of ${Object.keys(SCENES).join(", ")})`);
  const links = variant === "internal" ? errors.internal.links : [];
  const go = (s) => String(s).includes("{{");
  for (const [, p] of pages) for (const v of Object.values(p)) if (go(v)) throw new Error(`errors: "{{" in copy: ${v}`);
  for (const l of links) for (const v of Object.values(l)) if (go(v)) throw new Error(`errors: "{{" in copy: ${v}`);
  if (go(css) || go(logo)) throw new Error("errors: \"{{\" in the inlined CSS or logo would break the Go template");

  // One if / else-if chain per slot: the codes with their own page, then the fallback.
  const sample = { label: "Error 599", title: "Unknown Status Code", caption: "", scene: fallback.scene };
  const slot = (pick) =>
    preview
      ? pick(new Map(pages).get(preview) ?? sample)
      : pages.map(([code, p], i) => `{{ ${i ? "else if" : "if"} eq .StatusCode ${code} }}${pick(p)}`).join("") +
        `{{ else }}${pick(fallback)}{{ end }}`;

  // Set by Traefik's request-id plugin; error-pages exposes it with --show-details.
  const requestId = preview
    ? `<p class="bh-request">Request ID <code>3f6c1e2a-9b4d-4c8e-a1f0-7d2b5e9c0a14</code></p>`
    : `{{ if .RequestID }}<p class="bh-request">Request ID <code>{{ .RequestID | escape }}</code></p>{{ end }}`;

  // The crab is drawn once; each code only picks its scene, props and spot.
  const props = (list = []) => list.map((p) => sprite(p, logo)).join("");

  const row = (l) => `		<a class="bh-row" href="${esc(l.href)}">
			<span class="bh-row-name">${esc(l.name)}</span>
			<span class="bh-row-note">${esc(l.note)}</span>
			<span class="bh-row-go" aria-hidden="true">-&gt;</span>
		</a>`;
  const sheet = links.length
    ? `	<section class="bh-sheet" aria-labelledby="bh-tools-label">
		<h2 class="bh-section" id="bh-tools-label">${esc(errors.internal.heading)}</h2>
${links.map(row).join("\n")}
	</section>
`
    : "";

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${slot((p) => `${p.label} · ${p.title}`)}</title>
<style>
${css}
</style>
</head>
<body>
<main class="bh-home">
	<section class="bh-specimen">
		${slot((p) => `<p class="bh-label">${p.label}</p>
		<h1 class="bh-display">${p.title}</h1>
		<p class="bh-caption">${p.caption}</p>`)}
		${requestId}
		<div class="bh-stage bh-scene-${slot((p) => p.scene)}" aria-hidden="true">${slot((p) => props(SCENES[p.scene].behind))}<div class="bh-crab" style="${slot((p) => place(SCENES[p.scene].crab.x, 0))}">${crab(logo)}</div>${slot((p) => props(SCENES[p.scene].front))}</div>
	</section>
${sheet}</main>
</body>
</html>
`;
}
