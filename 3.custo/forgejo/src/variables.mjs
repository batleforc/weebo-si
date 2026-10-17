// The mapping from BatleHub tokens to Forgejo's theme variables.
// Edit here to change *what a token is used for*; edit theme.config.mjs to change its value.
import { hex, mix } from "./color.mjs";

const kebab = (s) => s.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());

export function variables(rendition, t, fonts) {
  const dark = rendition === "dark";
  const { ground: g, ink, inkDim: dim, accent: acc, copper: cop, green: grn, ruleSoft: sec } = t;
  const v = [];
  const add = (k, val) => v.push([k, val]);

  add("--is-dark-theme", String(dark));
  // Tokens exposed as-is for rules.css
  for (const k of ["ground", "groundRaised", "groundSunk", "ink", "inkDim", "ruleSoft", "ruleStrong", "accent", "accentInk", "copper", "focus"]) {
    add("--bh-" + kebab(k).replace("ground-", ""), hex(t[k]));
  }

  // primary = crimson. "dark-N" moves toward the ink pole, "light-N" toward the ground.
  const w7 = [0.1, 0.2, 0.3, 0.4, 0.6, 0.8, 0.93];
  add("--color-primary", hex(acc));
  add("--color-primary-contrast", hex(t.accentInk));
  w7.forEach((w, i) => add(`--color-primary-dark-${i + 1}`, hex(mix(acc, ink, w))));
  w7.forEach((w, i) => add(`--color-primary-light-${i + 1}`, hex(mix(acc, g, w))));
  for (let a = 10; a < 100; a += 10) add(`--color-primary-alpha-${a}`, hex(acc, a / 100));
  add("--color-primary-hover", "var(--color-primary-dark-1)");
  add("--color-primary-active", "var(--color-primary-dark-2)");

  // secondary = the soft rule (Forgejo draws most borders with it)
  add("--color-secondary", hex(sec));
  for (let i = 1; i < 14; i++) add(`--color-secondary-dark-${i}`, hex(mix(sec, ink, i / 15)));
  for (let i = 1; i < 5; i++) add(`--color-secondary-light-${i}`, hex(mix(sec, g, i / 5)));
  for (let a = 10; a < 100; a += 10) add(`--color-secondary-alpha-${a}`, hex(sec, a / 100));
  add("--color-secondary-button", hex(t.ruleStrong));
  add("--color-secondary-hover", hex(dim));
  add("--color-secondary-active", hex(dim));

  // console (Actions logs)
  add("--color-console-fg", hex(ink));
  add("--color-console-fg-subtle", hex(dim));
  add("--color-console-bg", hex(t.groundSunk));
  add("--color-console-border", hex(sec));
  add("--color-console-hover-bg", hex(t.groundRaised));
  add("--color-console-active-bg", hex(t.groundRaised));
  add("--color-console-menu-bg", hex(g));
  add("--color-console-menu-border", hex(t.ruleStrong));

  // Named colours that carry state: crimson = refused, copper = waiting, green = passed.
  // Blue / teal / violet / purple / pink are deliberately left to the base theme.
  const step = dark ? 0.05 : -0.05;
  const family = (key, [L, C, H]) => {
    add(`--color-${key}`, hex([L, C, H]));
    add(`--color-${key}-light`, hex([L + step, C, H]));
    add(`--color-${key}-dark-1`, hex([L - step, C, H]));
    add(`--color-${key}-dark-2`, hex([L - 2 * step, C, H]));
  };
  family("red", acc);
  family("orange", cop);
  family("yellow", [cop[0], cop[1], 75]);
  family("green", grn);
  family("brown", [dark ? cop[0] - 0.08 : cop[0], cop[1] * 0.7, cop[2]]);
  add("--color-gold", hex(cop));
  add("--color-git", hex(acc));
  add("--color-ansi-red", hex(acc));
  add("--color-ansi-green", hex(grn));
  add("--color-ansi-yellow", hex(cop));
  add("--color-grey", hex(sec));
  add("--color-grey-light", hex(dim));

  // diff
  add("--color-diff-added-linenum-bg", hex(mix(g, grn, 0.22)));
  add("--color-diff-added-row-bg", hex(mix(g, grn, 0.13)));
  add("--color-diff-added-row-border", hex(mix(g, grn, 0.3)));
  add("--color-diff-added-word-bg", hex(mix(g, grn, 0.36)));
  add("--color-diff-removed-linenum-bg", hex(mix(g, acc, 0.24)));
  add("--color-diff-removed-row-bg", hex(mix(g, acc, 0.14)));
  add("--color-diff-removed-row-border", hex(mix(g, acc, 0.32)));
  add("--color-diff-removed-word-bg", hex(mix(g, acc, 0.4)));
  add("--color-diff-moved-row-bg", hex(mix(g, cop, 0.25)));
  add("--color-diff-moved-row-border", hex(cop));
  add("--color-diff-inactive", hex(t.groundRaised));

  // messages: the border and the ink carry the state, the fill only confirms it
  add("--color-error-border", hex(acc));
  add("--color-error-bg", hex(mix(g, acc, 0.12)));
  add("--color-error-bg-active", hex(mix(g, acc, 0.26)));
  add("--color-error-bg-hover", hex(mix(g, acc, 0.19)));
  add("--color-error-text", hex(mix(acc, ink, dark ? 0.35 : 0)));
  add("--color-success-border", hex(grn));
  add("--color-success-bg", hex(mix(g, grn, 0.1)));
  add("--color-success-text", hex(grn));
  add("--color-warning-border", hex(cop));
  add("--color-warning-bg", hex(mix(g, cop, 0.1)));
  add("--color-warning-text", hex(cop));
  add("--color-info-border", hex(t.ruleStrong));
  add("--color-info-bg", hex(t.groundRaised));
  add("--color-info-text", hex(ink));
  for (const [key, c] of [["red", acc], ["green", grn], ["yellow", cop], ["orange", cop]]) {
    add(`--color-${key}-badge`, hex(c));
    add(`--color-${key}-badge-bg`, hex(c, 0.1));
    add(`--color-${key}-badge-hover-bg`, hex(c, 0.3));
  }

  // surfaces and text
  add("--color-body", hex(g));
  add("--color-box-header", hex(t.groundSunk));
  add("--color-box-body", hex(g));
  add("--color-box-body-highlight", hex(t.groundRaised));
  add("--color-header-wrapper", hex(g));
  add("--color-text-dark", hex(ink));
  add("--color-text", hex(ink));
  add("--color-text-light", hex(mix(ink, dim, 0.35)));
  add("--color-text-light-1", hex(mix(ink, dim, 0.7)));
  add("--color-text-light-2", hex(dim));
  add("--color-text-light-3", hex(dim)); // ink-dim is the floor for small text
  add("--color-footer", "var(--color-nav-bg)");
  add("--color-timeline", hex(sec));
  add("--color-input-text", hex(ink));
  add("--color-input-background", hex(t.groundSunk));
  add("--color-input-toggle-background", hex(sec));
  add("--color-input-border", hex(t.ruleStrong));
  add("--color-input-border-hover", hex(dim));
  add("--color-light", hex(ink, 0.06));
  add("--color-light-border", hex(ink, 0.16));
  add("--color-hover", hex(ink, 0.08));
  add("--color-active", hex(ink, 0.12));
  add("--color-menu", hex(t.groundSunk));
  add("--color-card", hex(g));
  add("--color-button", hex(g));
  add("--color-markup-table-row", hex(ink, 0.05));
  add("--color-markup-code-block", hex(ink, 0.06));
  add("--color-markup-code-inline", hex(ink, 0.13));
  add("--color-code-bg", hex(t.groundSunk));
  add("--color-shadow", "#00000000");
  add("--color-secondary-bg", hex(t.groundRaised));
  add("--color-expand-button", hex(t.groundRaised));
  add("--color-placeholder-text", hex(dim));
  add("--color-editor-line-highlight", hex(t.groundRaised));
  add("--color-project-board-bg", hex(t.groundSunk));
  add("--color-caret", hex(ink));
  add("--color-reaction-bg", hex(ink, 0.06));
  add("--color-reaction-hover-bg", hex(acc, 0.3));
  add("--color-reaction-active-bg", hex(acc, 0.2));
  add("--color-tooltip-text", hex(g));
  add("--color-tooltip-bg", hex(ink));
  add("--color-nav-bg", hex(t.groundSunk));
  add("--color-nav-hover-bg", hex(t.groundRaised));
  add("--color-nav-text", hex(dim));
  add("--color-secondary-nav-bg", hex(g));
  add("--color-label-text", hex(ink));
  add("--color-label-bg", hex(dim, 0.25));
  add("--color-label-hover-bg", hex(dim, 0.45));
  add("--color-label-active-bg", hex(dim, 0.65));
  add("--color-accent", hex(acc));
  add("--color-small-accent", "var(--color-primary-light-5)");
  add("--color-highlight-fg", hex(cop));
  add("--color-highlight-bg", hex(mix(g, cop, 0.22)));
  add("--color-overlay-backdrop", hex(dark ? t.groundSunk : t.ink, 0.75));

  // shape + type
  const text = `"${fonts.text.family}", ${fonts.text.fallback}`;
  add("--border-radius", "0");
  add("--border-radius-medium", "0");
  add("--fonts-proportional", text);
  add("--fonts-override", text);
  add("--fonts-monospace", `${text}, var(--fonts-emoji)`);
  add("--bh-face-display", `"${fonts.display.family}", ${fonts.display.fallback}`);
  add("accent-color", "var(--color-accent)");
  add("color-scheme", rendition);
  return v;
}
