import test from "node:test";
import assert from "node:assert/strict";
import { contrast, hex, parseOklch } from "../src/color.mjs";
import cfg from "../theme.config.mjs";

const t = (r, k) => parseOklch(cfg.tokens[r][k]);
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 0.02, `${actual.toFixed(3)} vs ${expected}`);

test("ratios match the ones recorded in BatleHub's DESIGN.md", () => {
  near(contrast(t("dark", "ink"), t("dark", "ground")), 16.88);
  near(contrast(t("dark", "inkDim"), t("dark", "ground")), 5.62);
  near(contrast(t("dark", "accent"), t("dark", "ground")), 5.76);
  near(contrast(t("dark", "copper"), t("dark", "ground")), 8.06);
  near(contrast(t("light", "ink"), t("light", "ground")), 16.64);
  near(contrast(t("light", "accent"), t("light", "ground")), 5.63);
  near(contrast(t("light", "accentInk"), t("light", "accent")), 5.97);
});

test("crimson paints as documented", () => {
  assert.equal(hex(t("dark", "accent")), "#ff343d");
  assert.equal(hex(t("light", "accent")), "#c50220");
});

test("out-of-gamut input is clamped to a valid hex", () => {
  assert.match(hex([0.65, 0.4, 25]), /^#[0-9a-f]{6}$/);
});
