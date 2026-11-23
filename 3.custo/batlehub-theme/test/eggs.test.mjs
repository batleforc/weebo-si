import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { renderEggs } from "../src/eggs.mjs";
import { parseOklch } from "../src/color.mjs";
import cfg from "../theme.config.mjs";

const tokens = Object.fromEntries(
  ["light", "dark"].map((r) => [r, Object.fromEntries(Object.entries(cfg.tokens[r]).map(([k, v]) => [k, parseOklch(v)]))]),
);
const logo = readFileSync(new URL("../assets/img/theme/logo-ink.svg", import.meta.url), "utf8");
const parts = { tokens, logo };
const egg = { keys: "konami", title: "T", button: "B", href: "https://example.org/" };
const only = (extra) => ({ fonts: cfg.fonts, ...extra });

test("nothing configured, no script", () => {
  assert.equal(renderEggs("argocd", only({}), parts), null);
  assert.equal(renderEggs("errors", only({ idle: 10 }), parts), null, "no screensaver on the error pages");
});

test("every target's script is valid JS with its config written in", () => {
  for (const target of ["forgejo", "argocd", "errors"]) {
    const js = renderEggs(target, cfg, parts);
    new Function(js);
    assert.match(js, /const CFG = \{"eggs"/, target);
  }
  assert.match(renderEggs("argocd", only({ eggs: { argocd: [egg] } }), parts), /"ArrowUp","ArrowUp","ArrowDown"/);
  assert.match(renderEggs("argocd", only({ eggs: { argocd: [{ ...egg, keys: "sudo" }] } }), parts), /"s","u","d","o"/);
});

test("a season recolours each target in its own variables", () => {
  const s = (target) => renderEggs(target, only({ seasons: [{ name: "x", from: "12-01", to: "12-31", accent: { dark: "oklch(0.7 0.1 150)", light: "oklch(0.5 0.1 150)" } }] }), parts);
  assert.match(s("forgejo"), /data-theme='batlehub-dark'.*--color-primary:/s);
  assert.match(s("argocd"), /\.theme-dark \{\\n  --bh-accent:/);
  assert.match(s("errors"), /prefers-color-scheme: dark/);
});

test("bad config is refused", () => {
  const bad = (target, extra) => () => renderEggs(target, only(extra), parts);
  assert.throws(bad("argocd", { eggs: { argocd: [{ ...egg, href: "javascript:alert(1)" }] } }), /https/);
  assert.throws(bad("argocd", { eggs: { argocd: [{ ...egg, keys: "ab" }] } }), /keys/);
  assert.throws(bad("argocd", { eggs: { argocd: [{ ...egg, title: "" }] } }), /title/);
  assert.throws(bad("errors", { eggs: { errors: [{ keys: "konami", game: "tetris" }] } }), /unknown game/);
  assert.throws(bad("argocd", { seasons: [{ name: "x", from: "13-01", to: "12-31" }] }), /MM-DD/);
  assert.throws(bad("argocd", { seasons: [{ name: "x", from: "12-01", to: "12-31", parade: "ufo" }] }), /parade/);
});
