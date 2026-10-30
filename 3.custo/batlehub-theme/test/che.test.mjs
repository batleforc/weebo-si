import test from "node:test";
import assert from "node:assert/strict";
import { icoFromPng, renderCheCss, renderCheLogo, renderProductJson } from "../src/che.mjs";
import { parseOklch } from "../src/color.mjs";
import cfg from "../theme.config.mjs";
import { readFileSync } from "node:fs";

const tokens = Object.fromEntries(
  ["light", "dark"].map((r) => [r, Object.fromEntries(Object.entries(cfg.tokens[r]).map(([k, v]) => [k, parseOklch(v)]))]),
);
const css = renderCheCss({ tokens });

test("each rendition outranks PatternFly's own selector for it", () => {
  // branding.css loads before PatternFly: `:root` alone would lose.
  const [light, dark] = [/\nhtml:root \{([^}]*)\}/, /\nhtml:root\.pf-v6-theme-dark \{([^}]*)\}/].map((re) => css.match(re)[1]);
  const brand = (block) => block.match(/--pf-t--global--color--brand--default: (#\w+)/)[1];
  assert.notEqual(brand(light), brand(dark));
});

test("the logo is recoloured by the dashboard, not baked in", () => {
  const svg = renderCheLogo('<svg><path fill="#0E0C0A" d="M0 0h1v1h-1z"/></svg>');
  assert.match(svg, /<path class="outer-fill" fill="currentColor"/);
  assert.throws(() => renderCheLogo("<svg/>"));
});

test("product.json names the logo by a file the image has no .gz for", () => {
  const p = JSON.parse(renderProductJson(cfg.che));
  assert.equal(p.logoFile, "batlehub-logo.svg");
  assert.throws(() => renderProductJson({ ...cfg.che, links: cfg.che.links.slice(0, 2) }));
});

test("the .ico wraps the PNG as it is", () => {
  const png = readFileSync(new URL("../assets/img/favicon.png", import.meta.url));
  const ico = icoFromPng(png);
  assert.deepEqual([...ico.subarray(0, 6)], [0, 0, 1, 0, 1, 0]);
  assert.equal(ico.readUInt32LE(14), png.length);
  assert.ok(ico.subarray(22).equals(png));
});
