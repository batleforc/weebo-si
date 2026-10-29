import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { renderErrors } from "../src/errors.mjs";
import cfg from "../theme.config.mjs";

const logo = readFileSync(new URL("../assets/img/theme/logo-ink.svg", import.meta.url), "utf8");
const parts = { css: "body{}", logo };

test("one branch per configured code, then error-pages' own message", () => {
  assert.match(renderErrors(cfg.errors, parts, { variant: "external" }), /\{\{ else \}\}Error \{\{ \.StatusCode \}\} · \{\{ \.Message \| escape \}\}\{\{ end \}\}/);
  const html = renderErrors(cfg.errors, parts, { variant: "external" });
  assert.match(html, /bh-scene-\{\{ if eq \.StatusCode 400 \}\}garbled.*\{\{ else if eq \.StatusCode 404 \}\}lost.*\{\{ else if eq \.StatusCode 503 \}\}work.*\{\{ else \}\}dazed\{\{ end \}\}/s);
});

test("only the internal variant lists the tools", () => {
  const href = cfg.errors.internal.links[0].href;
  assert.ok(renderErrors(cfg.errors, parts, { variant: "internal" }).includes(href));
  assert.ok(!renderErrors(cfg.errors, parts, { variant: "external" }).includes("weebo.poc"));
});

test("the crab is cut into its moving parts", () => {
  const html = renderErrors(cfg.errors, parts, { variant: "external", preview: 404 });
  assert.ok(!html.includes("{{"));
  for (const cls of ["cr-claw-l", "cr-claw-r", "cr-eyes", "cr-body", "cr-legs-a", "cr-legs-b"])
    assert.match(html, new RegExp(`class="cr-part ${cls}" d="M\\d`), cls);
});

test("copy that would break the Go template is refused", () => {
  const errors = { ...cfg.errors, pages: { 404: { label: "x", title: "{{ oops }}", caption: "y", scene: "lost" } } };
  assert.throws(() => renderErrors(errors, parts, { variant: "external" }), /"\{\{" in copy/);
});

test("every configured code previews its own scene", () => {
  for (const [code, p] of Object.entries(cfg.errors.pages))
    assert.ok(renderErrors(cfg.errors, parts, { variant: "external", preview: Number(code) }).includes(`bh-scene-${p.scene}"`), code);
});

test("the request id is shown only when error-pages has one, escaped", () => {
  assert.ok(renderErrors(cfg.errors, parts, { variant: "external" }).includes("{{ if .RequestID }}<p class=\"bh-request\">Request ID <code>{{ .RequestID | escape }}</code></p>{{ end }}"));
});
