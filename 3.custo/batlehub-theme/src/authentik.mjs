// The BatleHub theme for Authentik: the brand's custom CSS, the files it points at, and the
// brand + flow settings the weebo-si auth chart reads.
//
// Authentik injects the brand CSS twice: once in <head> (where @font-face works), and once
// into every component's shadow root (where `:host` is the component). Its own stylesheets
// sit in cascade layers, so this unlayered CSS wins without !important. The CSS reaches
// <head> through Django's json_script escaping, which turns < > & into <… and breaks
// any rule holding one: renderAuthentikCss refuses them.
import { hex, mix } from "./color.mjs";

// Authentik's themes, as substituted for %(theme)s in a brand's logo / favicon / background.
export const AK_THEMES = ["light", "dark"];

// Colour variables for one rendition. `self` is the rendition's tokens, `light` / `dark`
// both sets: PatternFly's "-light-N" variants are meant for dark surfaces and "-dark-N"
// for light ones, which in Authentik's light mode exist side by side (the login header
// over the background image). In dark mode Authentik collapses both onto the dark values,
// and so does this.
export function akVariables(rendition, tk, fonts) {
  const t = tk[rendition];
  const onDark = rendition === "dark" ? t : tk.dark; // for "-light-N": surfaces that are dark
  const onLight = rendition === "dark" ? t : tk.light; // for "-dark-N": surfaces that are light
  const v = [];
  const add = (k, val) => v.push([k, val]);
  const shades = (x) => ({
    100: x.ground,
    150: mix(x.ground, x.groundRaised, 0.5),
    200: x.groundSunk,
    300: x.groundRaised,
    400: mix(x.groundRaised, x.ruleSoft, 0.5),
  });

  // surfaces
  const bg = shades(t);
  for (const n of [100, 150, 200, 300, 400]) add(`--pf-global--BackgroundColor--${n}`, hex(bg[n]));
  const bgOnDark = shades(onDark);
  for (const n of [100, 200, 300]) add(`--pf-global--BackgroundColor--light-${n}`, hex(bgOnDark[n]));
  const bgDark = shades(tk.dark);
  for (const n of [100, 200, 300, 400]) add(`--pf-global--BackgroundColor--dark-${n}`, hex(bgDark[n]));
  add("--pf-global--BackgroundColor--dark-transparent-100", hex(tk.dark.groundSunk, 0.62));
  add("--pf-global--BackgroundColor--dark-transparent-200", hex(tk.dark.groundSunk, 0.32));
  add("--ak-dark-background", hex(tk.dark.groundSunk));
  add("--ak-dark-background-light", hex(tk.dark.ground));
  add("--ak-dark-background-lighter", hex(tk.dark.groundRaised));
  add("--ak-dark-foreground", hex(tk.dark.ink));
  add("--ak-v2-global--BackgroundColor--100", hex(t.ground));
  add("--ak-v2-global--BackgroundColor--200", hex(t.groundSunk));

  // text
  add("--pf-global--Color--100", hex(t.ink));
  add("--pf-global--Color--200", hex(t.inkDim));
  add("--pf-global--Color--300", hex(t.ink));
  add("--pf-global--Color--400", hex(t.inkDim));
  add("--pf-global--Color--dark-100", hex(onLight.ink));
  add("--pf-global--Color--dark-200", hex(onLight.inkDim));
  add("--pf-global--Color--light-100", hex(onDark.ink));
  add("--pf-global--Color--light-200", hex(onDark.inkDim));
  add("--pf-global--Color--light-300", hex(onDark.ruleSoft));
  add("--pf-global--icon--Color--dark", hex(onLight.inkDim));
  add("--pf-global--icon--Color--light", hex(onDark.inkDim));
  add("--ak-v2-global--Color--100", hex(t.ink));
  add("--ak-v2-global--Color--200", hex(t.inkDim));
  add("--ak-c-placeholder--Color", hex(t.inkDim));

  // rules
  add("--pf-global--BorderColor--100", hex(t.ruleSoft));
  add("--pf-global--BorderColor--200", hex(t.ruleStrong));
  add("--pf-global--BorderColor--300", hex(t.ruleSoft));
  add("--pf-global--BorderColor--400", hex(t.ruleStrong));
  add("--pf-global--BorderColor--dark-100", hex(onLight.ruleSoft));
  add("--pf-global--BorderColor--light-100", hex(onDark.ruleStrong));
  add("--ak-v2-global--BorderColor--100", hex(t.ruleSoft));
  add("--ak-v2-global--BorderColor--200", hex(t.ruleStrong));

  // crimson: primary, links, the active item
  const hover = (x) => mix(x.accent, x.ink, 0.25);
  add("--ak-accent", hex(t.accent));
  add("--pf-global--primary-color--100", hex(t.accent));
  add("--pf-global--primary-color--200", hex(hover(t)));
  add("--pf-global--primary-color--light-100", hex(onDark.accent));
  add("--pf-global--primary-color--dark-100", hex(onLight.accent));
  add("--pf-global--link--Color", hex(t.accent));
  add("--pf-global--link--Color--hover", hex(hover(t)));
  add("--pf-global--link--Color--visited", hex(t.accent));
  add("--pf-global--link--Color--light", hex(onDark.accent));
  add("--pf-global--link--Color--light--hover", hex(hover(onDark)));
  add("--pf-global--link--Color--dark", hex(onLight.accent));
  add("--pf-global--link--Color--dark--hover", hex(hover(onLight)));
  add("--pf-global--active-color--100", hex(t.accent));
  add("--pf-global--active-color--200", hex(mix(t.accent, t.ground, 0.8)));
  add("--pf-global--active-color--300", hex(t.accent));
  add("--pf-global--active-color--400", hex(hover(t)));

  // state: crimson = refused, copper = waiting, green = passed. Info stays Authentik's blue.
  add("--pf-global--danger-color--100", hex(t.accent));
  add("--pf-global--danger-color--200", hex(hover(t)));
  add("--pf-global--danger-color--300", hex(mix(t.ground, t.accent, 0.14)));
  add("--pf-global--warning-color--100", hex(t.copper));
  add("--pf-global--warning-color--200", hex(mix(t.copper, t.ink, 0.25)));
  add("--pf-global--success-color--100", hex(t.green));
  add("--pf-global--success-color--200", hex(mix(t.green, t.ink, 0.25)));
  add("--pf-global--disabled-color--100", hex(t.inkDim));
  add("--pf-global--disabled-color--200", hex(t.ruleSoft));
  add("--pf-global--disabled-color--300", hex(t.groundRaised));

  add("--ak-scrollbar-background-color", hex(t.groundSunk));
  add("--ak-scrollbar-thumb-background-color", hex(t.ruleStrong));

  // shape + type (the same in both renditions, repeated so a shadow root that only
  // matches the dark block still gets them)
  const flat = "0 0 #0000";
  for (const size of ["sm", "md", "lg"])
    for (const side of ["", "-top", "-right", "-bottom", "-left"]) add(`--pf-global--BoxShadow--${size}${side}`, flat);
  add("--pf-global--BoxShadow--xl", flat);
  add("--pf-global--BoxShadow--inset", flat);
  add("--ak-v2-global--BoxShadow--lg", flat);
  add("--pf-global--BorderRadius--sm", "0");
  add("--pf-global--BorderRadius--lg", "0");
  const text = `"${fonts.text.family}", ${fonts.text.fallback}`;
  add("--ak-generic-sans-serif", text);
  add("--ak-generic-monospace", text);
  add("--ak-generic-display", `"${fonts.display.family}", ${fonts.display.fallback}`);
  add("color-scheme", rendition);
  return v;
}

// The component rules: zero radius, flat at rest, the amber focus ring, crimson buttons.
// Plain descendant selectors only -- no `>` (see the header).
const rules = (assets) => `
*,
*::before,
*::after {
  border-radius: 0 !important;
}
input[type="radio"],
.pf-c-radio__input {
  border-radius: 50% !important;
}
:focus-visible {
  outline: 2px solid var(--bh-focus) !important;
  outline-offset: 2px;
}
body,
:host {
  font-variant-numeric: tabular-nums;
}

/* Primary actions: crimson, with the ink each rendition pairs it with. */
.pf-c-button.pf-m-primary {
  --pf-c-button--m-primary--BackgroundColor: var(--bh-accent);
  --pf-c-button--m-primary--Color: var(--bh-accent-ink);
  --pf-c-button--m-primary--hover--BackgroundColor: var(--bh-accent-hover);
  --pf-c-button--m-primary--hover--Color: var(--bh-accent-ink);
  --pf-c-button--m-primary--focus--BackgroundColor: var(--bh-accent-hover);
  --pf-c-button--m-primary--focus--Color: var(--bh-accent-ink);
  --pf-c-button--m-primary--active--BackgroundColor: var(--bh-accent-hover);
  --pf-c-button--m-primary--active--Color: var(--bh-accent-ink);
  font-family: var(--bh-face-display);
  font-size: 16px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
/* Floats are a 1px frame, not a shadow. */
.pf-c-login__main,
.pf-c-modal-box,
.pf-c-dropdown__menu,
.pf-c-select__menu,
.pf-c-options-menu__menu,
.pf-c-popover__content {
  border: 1px solid var(--bh-rule-strong);
}

/* Titles: the bitmap face, only at integer multiples of 8px. */
.pf-c-login__main-header .pf-c-title,
.pf-c-page__main-section .pf-c-title.pf-m-2xl,
.pf-c-modal-box__title {
  font-family: var(--bh-face-display);
  font-size: 24px;
  font-weight: 400;
  line-height: 1.33;
  letter-spacing: 0.02em;
}
.pf-c-form__label-text,
.pf-c-table thead th {
  font-size: 12px;
  font-weight: 400;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--bh-ink-dim);
}

/* The logo is pixel art: keep its pixels square. */
.pf-c-brand,
.pf-c-login__header img,
.pf-c-page__header-brand img,
img[src*="${assets}/logo-"] {
  image-rendering: pixelated;
}
`;

/**
 * The brand's custom CSS.
 * @param {{tokens: {light: object, dark: object}, fonts: object, assets: string}} p
 *   `assets`: the URL path the files from authentikFiles() are served under.
 */
export function renderAuthentikCss({ tokens, fonts, assets }) {
  const block = (r) => {
    const t = tokens[r];
    const own = [
      ["--bh-accent", hex(t.accent)],
      ["--bh-accent-ink", hex(t.accentInk)],
      ["--bh-accent-hover", hex(mix(t.accent, t.ink, 0.25))],
      ["--bh-ink-dim", hex(t.inkDim)],
      ["--bh-rule-strong", hex(t.ruleStrong)],
      ["--bh-focus", hex(t.focus)],
      ["--bh-face-display", `"${fonts.display.family}", ${fonts.display.fallback}`],
    ];
    return [...akVariables(r, tokens, fonts), ...own].map(([k, val]) => `  ${k}: ${val};`).join("\n");
  };
  const faces = Object.values(fonts)
    .flatMap((face) =>
      face.files.map(
        (f) => `@font-face {
  font-family: "${face.family}";
  src: url("${assets}/fonts/${f.file}") format("woff2");
  font-weight: ${f.weight};
  font-display: swap;
}`,
      ),
    )
    .join("\n");
  const css = `/* BatleHub for Authentik. Generated by 3.custo/batlehub-theme; edit there and rebuild. */
${faces}

:root,
:host {
${block("light")}
}
html[data-theme="dark"],
:host([theme="dark"]) {
${block("dark")}
}
${rules(assets)}`;
  const bad = /[<>&]/.exec(css);
  if (bad) {
    const line = css.slice(0, bad.index).split("\n").length;
    throw new Error(`Authentik CSS line ${line}: "${bad[0]}" would be escaped to \\u00XX in <head> and break the rule`);
  }
  return css;
}

/**
 * The page behind every flow, one per Authentik theme: the ground, and the halftone plate
 * inked in its rendition's colour along the right edge. An SVG used as a background image
 * cannot fetch anything, so the plate is inlined.
 */
export function renderBackground({ ground, ink, opacity }, platePng) {
  const plate = `data:image/png;base64,${platePng.toString("base64")}`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid slice">
<defs><mask id="p" maskUnits="userSpaceOnUse" x="0" y="0" width="1600" height="900" style="mask-type:alpha">
<image href="${plate}" width="1600" height="900" preserveAspectRatio="xMaxYMid slice" transform="translate(1600 0) scale(-1 1)"/>
</mask></defs>
<rect width="1600" height="900" fill="${ground}"/>
<rect width="1600" height="900" fill="${ink}" opacity="${opacity}" mask="url(#p)"/>
</svg>
`;
}

/**
 * Brand and flow settings for the auth chart, as YAML. Paths are what Authentik stores:
 * `%(theme)s` is replaced by light / dark when it serves them.
 */
export function renderBrandYaml(ak, assets) {
  const q = (s) => JSON.stringify(s);
  const flows = Object.entries(ak.flows || {})
    .map(([slug, f]) => {
      if (!/^[a-z0-9-]+$/.test(slug)) throw new Error(`authentik.flows: bad slug ${slug}`);
      const lines = [`  ${slug}:`, `    title: ${q(f.title)}`];
      if (f.layout) lines.push(`    layout: ${f.layout}`);
      return lines.join("\n");
    })
    .join("\n");
  return `# Generated by 3.custo/batlehub-theme (npm run build). Do not edit.
title: ${q(ak.title)}
logo: ${q(`${assets}/logo-%(theme)s.svg`)}
favicon: ${q(`${assets}/favicon.svg`)}
background: ${q(`${assets}/background-%(theme)s.svg`)}
flows:
${flows || "  {}"}
`;
}
