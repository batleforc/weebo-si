import test from "node:test";
import assert from "node:assert/strict";
import { renderAuthentikCss, renderBrandYaml, renderBackground } from "../src/authentik.mjs";
import { parseOklch } from "../src/color.mjs";
import cfg from "../theme.config.mjs";

const tokens = Object.fromEntries(
  ["light", "dark"].map((r) => [r, Object.fromEntries(Object.entries(cfg.tokens[r]).map(([k, v]) => [k, parseOklch(v)]))]),
);
const css = renderAuthentikCss({ tokens, fonts: cfg.fonts, assets: "/static/dist/assets/batlehub" });

test("nothing Authentik's <head> escaping would mangle", () => {
  assert.doesNotMatch(css, /[<>&]/);
});

test("each rendition sets the colours, in the document and in shadow roots", () => {
  assert.match(css, /:root,\n:host \{[^}]*--pf-global--BackgroundColor--100: #/);
  assert.match(css, /html\[data-theme="dark"\],\n:host\(\[theme="dark"\]\) \{[^}]*--pf-global--BackgroundColor--100: #/);
  const [light, dark] = [...css.matchAll(/--pf-global--BackgroundColor--100: (#\w+)/g)].map((m) => m[1]);
  assert.notEqual(light, dark);
});

test("fonts load from the mounted files", () => {
  for (const f of Object.values(cfg.fonts).flatMap((face) => face.files))
    assert.ok(css.includes(`url("/static/dist/assets/batlehub/fonts/${f.file}")`), f.file);
});

test("brand.yaml carries the themed paths and the flow copy", () => {
  const y = renderBrandYaml({ title: "T", flows: { "a-flow": { title: "Hi %(app)s", layout: "stacked" } } }, "/x");
  assert.match(y, /^logo: "\/x\/logo-%\(theme\)s\.svg"$/m);
  assert.match(y, /^  a-flow:\n    title: "Hi %\(app\)s"\n    layout: stacked$/m);
  assert.throws(() => renderBrandYaml({ title: "T", flows: { "Bad Slug": { title: "x" } } }, "/x"));
});

test("the background inlines the plate, nothing fetched", () => {
  const svg = renderBackground({ ground: "#000000", ink: "#ffffff", opacity: 0.3 }, Buffer.from("png"));
  assert.match(svg, /href="data:image\/png;base64,/);
  assert.doesNotMatch(svg, /href="(https?:|\/)/);
});

test("the flow background names each rendition's file, not %(theme)s", () => {
  assert.match(css, /\nbody::before \{\n  background-image: url\("\/static\/dist\/assets\/batlehub\/background-light\.svg"\);/);
  assert.match(css, /html\[data-theme="dark"\] body::before \{\n  background-image: url\("\/static\/dist\/assets\/batlehub\/background-dark\.svg"\);/);
});
