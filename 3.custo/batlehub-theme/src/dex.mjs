// The BatleHub theme for Dex: a theme directory (frontend.theme), dropped next to the stock
// ones in the image's own web directory. Dex serves it as `<issuer>/theme/`, and its
// header.html (left as the image ships it, so the templates always match the binary)
// loads `theme/styles.css` and `theme/favicon.png` from it, after `static/main.css`. The
// theme's stylesheet replaces the stock light / dark one entirely: every `theme-*` class
// the templates use is painted here.
//
// One stylesheet for both renditions: Dex has no theme switch, so the light one is the
// default and the dark one follows `prefers-color-scheme`. The navbar stays on the dark
// ground whichever applies, as Argo CD's sidebar does, so it carries the cream logo.
//
// Files sit flat next to the stylesheet (ConfigMap keys hold no `/`), which names them
// relative to itself. Re-check the class names after a Dex minor upgrade: one renamed in
// the templates falls back to main.css, it does not break the page.
import { hex, mix } from "./color.mjs";

export const CSS_FILE = "styles.css";
// Dex's header.html asks for theme/favicon.png by that name.
export const FAVICON_FILE = "favicon.png";
// What frontend.logoURL points at (theme/logo.svg); the stylesheet also swaps it in, so a
// Dex left on its default logoURL still shows the crab.
export const LOGO_FILE = "logo.svg";

const vars = (t) => [
  ["--bh-page", hex(t.groundSunk)],
  ["--bh-box", hex(t.ground)],
  ["--bh-raised", hex(t.groundRaised)],
  ["--bh-ink", hex(t.ink)],
  ["--bh-ink-dim", hex(t.inkDim)],
  ["--bh-rule-soft", hex(t.ruleSoft)],
  ["--bh-rule-strong", hex(t.ruleStrong)],
  ["--bh-accent", hex(t.accent)],
  ["--bh-accent-ink", hex(t.accentInk)],
  ["--bh-accent-hover", hex(mix(t.accent, t.ink, 0.25))],
  ["--bh-copper", hex(t.copper)],
  ["--bh-focus", hex(t.focus)],
  // What main.css reads for the home and logout pages.
  ["--dex-fg", hex(t.ink)],
  ["--dex-fg-muted", hex(t.inkDim)],
  ["--dex-border", hex(t.ruleSoft)],
  ["--dex-accent", hex(t.accent)],
];

const rules = (fonts, navbar) => {
  const display = `"${fonts.display.family}", ${fonts.display.fallback}`;
  const text = `"${fonts.text.family}", ${fonts.text.fallback}`;
  return [
    // ── Page: the flow background, the brand's faces ──────────────────────────
    `.theme-body {
  min-height: 100vh;
  background: var(--bh-page) url("background-light.svg") center / cover no-repeat fixed;
  color: var(--bh-ink);
  font-family: ${text};
  font-size: 14px;
}`,
    `@media (prefers-color-scheme: dark) {
  .theme-body {
    background-image: url("background-dark.svg");
  }
}`,
    `.dex-container {
  color: var(--bh-ink);
}`,
    // Not the connector buttons: they are links too, painted below.
    `.theme-body a:not(.dex-btn) {
  color: var(--bh-accent);
}`,

    // ── Navbar: always on the dark ground, the cream crab ─────────────────────
    `.theme-navbar {
  background-color: ${navbar.ground};
  border-bottom: 1px solid ${navbar.rule};
  color: ${navbar.inkDim};
  height: 56px;
  overflow: hidden;
  padding: 0 16px;
}`,
    `.theme-navbar__logo-wrap {
  display: inline-block;
  height: 100%;
  padding: 8px 0;
}`,
    // The 26 x 41 pixel crab, at its own size: scaling a bitmap drawing blurs it.
    `.theme-navbar__logo {
  content: url("${LOGO_FILE}");
  height: 41px;
  width: 26px;
  image-rendering: pixelated;
}`,

    // ── Panel: square, flat, one rule ─────────────────────────────────────────
    `.theme-panel {
  background-color: var(--bh-box);
  border: 1px solid var(--bh-rule-strong);
  border-radius: 0;
  box-shadow: none;
  padding: 32px;
}`,
    // The bitmap face, only at integer multiples of 8px.
    `.theme-heading {
  color: var(--bh-ink);
  font-family: ${display};
  font-size: 24px;
  font-weight: 400;
  letter-spacing: 0.02em;
  line-height: 1.34;
  margin: 0 0 24px;
}`,
    `.theme-panel p,
.dex-subtle-text,
.dex-separator,
.dex-list {
  color: var(--bh-ink-dim);
}`,

    // ── Buttons: crimson, square, labels in the display face ──────────────────
    `.dex-btn {
  border-radius: 0;
  font-family: ${display};
  font-size: 16px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}`,
    `.dex-btn-text {
  font-weight: 400;
}`,
    `.theme-btn-provider {
  background-color: var(--bh-accent);
  border: 1px solid var(--bh-accent);
  color: var(--bh-accent-ink);
  max-width: 100%;
  width: 280px;
}`,
    `.theme-btn-provider:hover {
  background-color: var(--bh-accent-hover);
  border-color: var(--bh-accent-hover);
  color: var(--bh-accent-ink);
}`,
    // Several connectors: the first one is the primary, the others are outlined.
    `.theme-form-row + .theme-form-row .theme-btn-provider {
  background-color: transparent;
  color: var(--bh-accent);
}`,
    `.theme-form-row + .theme-form-row .theme-btn-provider:hover {
  background-color: var(--bh-accent);
  color: var(--bh-accent-ink);
}`,
    `.theme-btn-provider .dex-btn-icon {
  margin-left: 8px;
}`,
    `.theme-btn--primary {
  background-color: var(--bh-accent);
  border: 1px solid var(--bh-accent);
  color: var(--bh-accent-ink);
  min-height: 40px;
  min-width: 200px;
  padding: 0 16px;
}`,
    `.theme-btn--primary:hover {
  background-color: var(--bh-accent-hover);
  color: var(--bh-accent-ink);
}`,
    `.theme-btn--success {
  background-color: transparent;
  border: 1px solid var(--bh-accent);
  color: var(--bh-accent);
  width: 280px;
}`,
    `.theme-btn--success:hover {
  background-color: var(--bh-accent);
  color: var(--bh-accent-ink);
}`,

    // ── Forms ─────────────────────────────────────────────────────────────────
    `.theme-form-row {
  display: block;
  margin: 16px auto;
}`,
    `.theme-form-label {
  color: var(--bh-ink-dim);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.1em;
  margin: 4px auto;
  position: relative;
  text-align: left;
  text-transform: uppercase;
  width: 280px;
}`,
    `.theme-form-input {
  background-color: var(--bh-page);
  border: 1px solid var(--bh-rule-strong);
  border-radius: 0;
  color: var(--bh-ink);
  display: block;
  font-family: ${text};
  font-size: 14px;
  height: 40px;
  line-height: 1.5;
  margin: auto;
  padding: 8px 12px;
  width: 280px;
}`,
    `.theme-form-input:focus,
.theme-form-input:active {
  border-color: var(--bh-accent);
  box-shadow: none;
  outline: none;
}`,
    `.theme-remember-me {
  align-items: center;
  cursor: pointer;
  display: flex;
  font-size: 14px;
  gap: 8px;
  margin: 4px auto;
  width: 280px;
}`,
    `.theme-remember-me input {
  accent-color: var(--bh-accent);
}`,
    `.theme-link-back {
  margin-top: 8px;
}`,
    `.dex-error-box {
  background-color: var(--bh-accent);
  border-radius: 0;
  color: var(--bh-accent-ink);
}`,

    // ── Shape: square everywhere, the amber focus ring ────────────────────────
    `.theme-body *,
.theme-body *::before,
.theme-body *::after {
  border-radius: 0 !important;
}`,
    `.theme-body :focus-visible {
  outline: 2px solid var(--bh-focus) !important;
  outline-offset: 2px;
}`,
  ];
};

/** The theme's styles.css. */
export function renderDexCss({ tokens, fonts }) {
  const block = (t) => vars(t).map(([k, v]) => `  ${k}: ${v};`).join("\n");
  const faces = Object.values(fonts)
    .flatMap((face) =>
      face.files.map(
        (f) => `@font-face {
  font-family: "${face.family}";
  src: url("${f.file}") format("woff2");
  font-weight: ${f.weight};
  font-display: swap;
}`,
      ),
    )
    .join("\n");
  const d = tokens.dark;
  const navbar = { ground: hex(d.groundSunk), rule: hex(d.ruleSoft), inkDim: hex(d.inkDim) };
  return `/* BatleHub for Dex. Generated by 3.custo/batlehub-theme; edit there and rebuild. */
${faces}

.theme-body {
${block(tokens.light)}
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  .theme-body {
${block(tokens.dark).replace(/^/gm, "  ")}
    color-scheme: dark;
  }
}

${rules(fonts, navbar).join("\n\n")}
`;
}
