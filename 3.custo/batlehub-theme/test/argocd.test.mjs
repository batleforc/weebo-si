import test from "node:test";
import assert from "node:assert/strict";
import { renderArgoCss } from "../src/argocd.mjs";
import { parseOklch } from "../src/color.mjs";
import cfg from "../theme.config.mjs";

const tokens = Object.fromEntries(
  ["light", "dark"].map((r) => [r, Object.fromEntries(Object.entries(cfg.tokens[r]).map(([k, v]) => [k, parseOklch(v)]))]),
);
const css = renderArgoCss({ tokens, fonts: cfg.fonts });

test("every themed rule also exists under .theme-dark", () => {
  // Argo CD's dark rules are `.theme-dark X`: a plain `X` from here loses to them.
  assert.match(css, /\.white-box,[^{]*\.theme-dark \.white-box,[^{]*\{/);
  assert.match(css, /\.argo-button--base,[^{]*\.theme-dark \.argo-button--base,[^{]*\{/);
});

test("filled buttons keep their ink: the plain button colour comes first", () => {
  assert.ok(css.indexOf(".argo-button,\n") < css.indexOf(".argo-button--base,\n"));
});

test("files are named next to the stylesheet: a ConfigMap key has no /", () => {
  for (const [, url] of css.matchAll(/url\("([^"]+)"\)/g)) assert.doesNotMatch(url, /\//, url);
});
