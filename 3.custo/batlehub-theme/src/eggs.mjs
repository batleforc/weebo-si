// Easter eggs: builds src/eggs.runtime.js into one script per target, with that
// target's config written in. Three things, all from theme.config.mjs:
//   eggs.<target>  a key sequence ("konami" or a word typed outside any text field)
//                  opens a dialog, or (error pages) turns the crab's stage into a game
//   seasons        a date range recolours the accent and sends a parade once a session
//   idle           minutes without input before the crab screensaver (Forgejo, Argo CD)
//
// Forgejo loads its script from templates/custom/footer.tmpl, Argo CD as a UI extension
// (/tmp/extensions on argocd-server, see 1.pulu-conf), the error pages inline it.
import { readFileSync } from "node:fs";
import { hex, parseOklch } from "./color.mjs";
import { variables } from "./variables.mjs";
import { vars as argoVars } from "./argocd.mjs";
import { rects } from "./errors.mjs";

export const FORGEJO_FILE = "batlehub-eggs.js";
// Argo CD only loads files named extension*.js under /tmp/extensions.
export const ARGOCD_FILE = "extension-batlehub-eggs.js";
export const FORGEJO_FOOTER = `<script src="{{AppSubUrl}}/assets/js/${FORGEJO_FILE}" defer></script>\n`;
export const TARGETS = ["forgejo", "argocd", "errors"];

const RUNTIME = readFileSync(new URL("./eggs.runtime.js", import.meta.url), "utf8");
const KONAMI = ["ArrowUp", "ArrowUp", "ArrowDown", "ArrowDown", "ArrowLeft", "ArrowRight", "ArrowLeft", "ArrowRight", "b", "a"];
const GAMES = ["crab-run", "shelf-climb"];
const PARADES = ["bats", "snow", "crab"];

const ascii = (art) => [
  art[0].length,
  art.length,
  art.flatMap((line, y) => [...line.matchAll(/#+/g)].map((m) => `M${m.index} ${y}h${m[0].length}v1h-${m[0].length}z`)).join(""),
];
const BAT = ascii(["##.........##", "###..#.#..###", "#############", ".###########.", "..##.###.##..", ".....#.#....."]);
const BUG = ascii(["#.....#", ".#####.", "#######", ".#####.", "#.#.#.#"]);
const sequence = (keys) => {
  if (keys === "konami") return KONAMI;
  if (typeof keys !== "string" || !/^[a-z0-9]{3,}$/.test(keys)) throw new Error(`eggs: keys must be "konami" or a word of 3+ lowercase letters / digits: ${keys}`);
  return [...keys];
};

const egg = (e) => {
  const seq = sequence(e.keys);
  if (e.game) {
    if (!GAMES.includes(e.game)) throw new Error(`eggs: unknown game "${e.game}" (one of ${GAMES.join(", ")})`);
    return { seq, game: e.game };
  }
  for (const k of ["title", "button"]) if (typeof e[k] !== "string" || !e[k]) throw new Error(`eggs: ${k} is required`);
  if (e.href !== undefined && !/^https:\/\//.test(e.href)) throw new Error(`eggs: href must be an https URL: ${e.href}`);
  return { seq, title: e.title, text: e.text, button: e.button, href: e.href };
};

/** Base tokens with a season's accent (and accentInk) swapped in, per rendition. */
export function seasonTokens(season, tokens) {
  return Object.fromEntries(
    Object.entries(tokens).map(([r, t]) => [
      r,
      { ...t, ...Object.fromEntries(["accent", "accentInk"].filter((k) => season[k]?.[r]).map((k) => [k, parseOklch(season[k][r])])) },
    ]),
  );
}

const block = (sel, list) => `${sel} {\n${list.map(([k, v]) => `  ${k}: ${v};`).join("\n")}\n}`;
const accentOnly = (list) => list.filter(([k]) => /accent|primary/.test(k));

// The season's colours in each target's own variables, scoped to the BatleHub theme.
function seasonCss(target, t, fonts) {
  const egg = `:root {\n  --bh-egg-ink: ${hex(t.dark.accent)};\n}`;
  if (target === "forgejo") {
    const f = (r) => accentOnly(variables(r, t[r], fonts));
    return [
      egg,
      block(":root[data-theme='batlehub-light']", f("light")),
      block(":root[data-theme='batlehub-dark']", f("dark")),
      `@media (prefers-color-scheme: light) {\n${block(":root[data-theme='batlehub-auto']", f("light"))}\n}`,
      `@media (prefers-color-scheme: dark) {\n${block(":root[data-theme='batlehub-auto']", f("dark"))}\n}`,
    ].join("\n");
  }
  if (target === "argocd")
    return [egg, block(":root,\n.theme-light", accentOnly(argoVars(t.light))), block(".theme-dark", accentOnly(argoVars(t.dark)))].join("\n");
  const bh = (r) => [["--bh-accent", hex(t[r].accent)], ["--bh-accent-ink", hex(t[r].accentInk)]];
  return [egg, block(":root", bh("light")), `@media (prefers-color-scheme: dark) {\n${block(":root", bh("dark"))}\n}`].join("\n");
}

const staticCss = (t) => `
.bh-egg { background: ${hex(t.ground)}; color: ${hex(t.ink)}; border: 2px solid ${hex(t.accent)}; border-radius: 0; padding: 32px 40px; max-width: min(560px, calc(100vw - 32px)); text-align: center; font-family: inherit; }
.bh-egg::backdrop { background: rgb(0 0 0 / 0.7); }
.bh-egg h2 { margin: 0 0 16px; font-size: 28px; letter-spacing: 0.12em; color: ${hex(t.accent)}; }
.bh-egg p { margin: 0 0 24px; color: ${hex(t.inkDim)}; }
.bh-egg-go { display: inline-block; padding: 12px 20px; border: 0; border-radius: 0; background: ${hex(t.accent)}; color: ${hex(t.accentInk)}; font: inherit; font-weight: 700; letter-spacing: 0.1em; text-decoration: none; cursor: pointer; }
.bh-egg-go:focus-visible, .bh-egg-x:focus-visible { outline: 3px solid ${hex(t.focus)}; outline-offset: 3px; }
.bh-egg-x { position: absolute; top: 4px; right: 8px; background: none; border: 0; color: ${hex(t.inkDim)}; font-size: 24px; cursor: pointer; }
@media (prefers-reduced-motion: no-preference) { .bh-egg h2 { animation: bh-egg-blink 1s steps(2) infinite; } }
@keyframes bh-egg-blink { 50% { opacity: 0.35; } }

.bh-parade { position: fixed; inset: 0; z-index: 2147483000; overflow: hidden; pointer-events: none; }
.bh-parade i { position: absolute; display: block; }
.bh-parade svg { display: block; width: 100%; shape-rendering: crispEdges; }
.bh-parade-bats i { left: -60px; top: var(--y); width: 52px; color: var(--bh-egg-ink); animation: bh-fly 9s linear var(--d) both; }
.bh-parade-snow i { left: var(--x); top: -8px; width: 6px; height: 6px; background: #eef4fb; outline: 1px solid #8ea4bb; animation: bh-fall 9s linear var(--d) both; }
.bh-parade-crab i { left: -110px; bottom: 8px; width: 104px; color: var(--bh-egg-ink); animation: bh-walk 14s linear both; }
.bh-parade-crab svg { transform: scaleY(-1); }
@keyframes bh-fly { 25% { transform: translate(28vw, -5vh); } 50% { transform: translate(55vw, 4vh); } 75% { transform: translate(80vw, -3vh); } to { transform: translate(calc(100vw + 120px), 0); } }
@keyframes bh-fall { to { transform: translate(5vw, 105vh); } }
@keyframes bh-walk { to { transform: translateX(calc(100vw + 220px)); } }

.bh-saver { position: fixed; inset: 0; z-index: 2147483001; background: ${hex(t.groundSunk)}; color: var(--bh-egg-ink, ${hex(t.accent)}); cursor: none; }
.bh-saver-x { position: absolute; top: 0; left: 0; animation: bh-sx 13s linear infinite alternate; }
.bh-saver-y { animation: bh-sy 7s linear infinite alternate; }
.bh-saver svg { display: block; width: 156px; height: 78px; shape-rendering: crispEdges; }
@keyframes bh-sx { to { transform: translateX(calc(100vw - 156px)); } }
@keyframes bh-sy { to { transform: translateY(calc(100vh - 78px)); } }
@media (prefers-reduced-motion: reduce) {
  .bh-saver-x, .bh-saver-y { animation: none; }
  .bh-saver-x { top: calc(50% - 39px); left: calc(50% - 78px); }
}

.bh-stage .bh-game { display: block; width: 100%; height: 100%; touch-action: manipulation; }
.bh-stage .bh-game:focus-visible { outline: 3px solid var(--bh-focus); outline-offset: -3px; }
`;

const SEASON_NAME = /^[a-z][a-z-]*$/;
const MONTH_DAY = /^(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;

/**
 * The script for one target, or null when nothing applies to it. `cfg` is the whole
 * theme config, `logo` the pixel logo SVG (its rows 0-12 are the crab).
 */
export function renderEggs(target, cfg, { tokens, logo }) {
  if (!TARGETS.includes(target)) throw new Error(`eggs: unknown target "${target}"`);
  const eggs = (cfg.eggs?.[target] ?? []).map(egg);
  const seasons = (cfg.seasons ?? []).map((s) => {
    if (!SEASON_NAME.test(s.name ?? "")) throw new Error(`seasons: name must be lowercase letters and dashes: ${s.name}`);
    for (const k of ["from", "to"]) if (!MONTH_DAY.test(s[k] ?? "")) throw new Error(`seasons: ${s.name}.${k} must be MM-DD: ${s[k]}`);
    if (s.parade && !PARADES.includes(s.parade)) throw new Error(`seasons: unknown parade "${s.parade}" (one of ${PARADES.join(", ")})`);
    return { name: s.name, from: s.from, to: s.to, parade: s.parade, css: seasonCss(target, seasonTokens(s, tokens), cfg.fonts) };
  });
  const idle = target === "errors" ? 0 : (cfg.idle ?? 0);
  if (!(idle >= 0)) throw new Error(`idle: minutes, or 0 for none: ${cfg.idle}`);
  if (!eggs.length && !seasons.length && !idle) return null;
  const crab = rects(logo).filter((r) => r.y <= 12).map((r) => `M${r.x} ${r.y}h${r.w}v1h-${r.w}z`).join("");
  const config = { eggs, seasons, idle, css: staticCss(tokens.dark), sprites: { crab: [26, 13, crab], bat: BAT, bug: BUG } };
  const HOLE = "const CFG = __CFG__;";
  if (!RUNTIME.includes(HOLE)) throw new Error(`eggs: ${HOLE} not found in eggs.runtime.js`);
  return `// Generated by 3.custo/batlehub-theme (src/eggs.mjs, src/eggs.runtime.js). Do not edit.\n${RUNTIME.replace(HOLE, () => `const CFG = ${JSON.stringify(config)};`)}`;
}
