import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { renderDexCss } from "../src/dex.mjs";
import { parseOklch } from "../src/color.mjs";
import cfg from "../theme.config.mjs";

const tokens = Object.fromEntries(
  ["light", "dark"].map((r) => [r, Object.fromEntries(Object.entries(cfg.tokens[r]).map(([k, v]) => [k, parseOklch(v)]))]),
);
const css = renderDexCss({ tokens, fonts: cfg.fonts });

test("files are named next to the stylesheet: a ConfigMap key has no /", () => {
  for (const [, url] of css.matchAll(/url\("([^"]+)"\)/g)) assert.doesNotMatch(url, /\//, url);
});

test("the dark rendition follows the device", () => {
  assert.match(css, /@media \(prefers-color-scheme: dark\) \{\s*\.theme-body \{[^}]*--bh-page:/);
});

test("every theme-* class Dex's templates use is painted", () => {
  // The stock theme's stylesheet is replaced, not extended: a class missing here keeps
  // only main.css's look. The list is what Dex v2.46's templates and stock themes use.
  const stock = readFileSync(new URL("./fixtures/dex-theme-classes.txt", import.meta.url), "utf8").split(/\s+/).filter(Boolean);
  for (const cls of stock) assert.match(css, new RegExp(`\\.${cls}\\b`), cls);
});
