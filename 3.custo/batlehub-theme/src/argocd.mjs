// The BatleHub theme for the Argo CD UI: one stylesheet (ui.cssurl), and the files it
// points at, served by argocd-server from /shared/app/custom (the argocd-styles-cm
// ConfigMap the chart mounts there). ConfigMap keys cannot hold a `/`: every file sits
// next to the stylesheet, which names them relative to itself.
//
// Argo CD's styles are compiled SCSS with the colours written in, no variables, so this
// overrides the rules that paint the main surfaces, one by one. The UI appends the
// ui.cssurl sheet after its own, so a rule wins at equal specificity: each one is written
// twice, plain for the light theme and under `.theme-dark` for the dark one, matching
// the selectors Argo CD uses. The theme class sits on a <div> around the whole app,
// login page included; the <body> behind it gets an inline background from a script.
//
// Re-check after an Argo CD minor upgrade: a renamed class falls back to Argo CD's look,
// it does not break the page.
import { hex, mix } from "./color.mjs";

export const CSS_FILE = "batlehub.css";

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
  ["--bh-accent-wash", hex(mix(t.ground, t.accent, 0.14))],
  ["--bh-focus", hex(t.focus)],
];

// `X, Y { … }` -> `X, Y, .theme-dark X, .theme-dark Y { … }`
function both(selectors, body) {
  const list = selectors.split(",").map((s) => s.trim());
  return `${[...list, ...list.map((s) => `.theme-dark ${s}`)].join(",\n")} {\n${body.trim().replace(/^\s*/gm, "  ")}\n}`;
}

const rules = (fonts, sidebar) => [
  // ── Surfaces ──────────────────────────────────────────────────────────────
  `body {\n  background: ${sidebar.lightPage} !important;\n}\nbody:has(.theme-dark) {\n  background: ${sidebar.darkPage} !important;\n}`,
  both(".layout", "background-color: var(--bh-page);"),
  both(
    ".white-box, .argo-table-list__row, .top-bar, .tabs__nav, .application-status-panel, .application-resource-tree__node, .argo-dropdown__content, .select__options",
    "background-color: var(--bh-box);\ncolor: var(--bh-ink);\nbox-shadow: none;\nborder: 1px solid var(--bh-rule-soft);",
  ),
  both(".top-bar, .tabs__nav", "border-width: 0 0 1px;"),
  both(
    ".popup-overlay .popup-container__body, .popup-overlay .popup-container__footer, .sliding-panel__wrapper, .sliding-panel__body",
    "background-color: var(--bh-box);\ncolor: var(--bh-ink);",
  ),
  both(
    ".popup-overlay .popup-container__header__normal, .sliding-panel__header, .sliding-panel--off-canvas .sliding-panel__header",
    "background-color: var(--bh-raised);\ncolor: var(--bh-ink);\nborder-color: var(--bh-rule-soft);",
  ),
  both(".popup-overlay .popup-container", "border: 1px solid var(--bh-rule-strong);\nbox-shadow: none;"),
  both(".argo-dropdown__content.is-menu ul li:hover, .argo-table-list__row:hover", "background-color: var(--bh-raised);"),
  both(".argo-table-list__row.selected", "background-color: var(--bh-accent-wash);"),

  // ── Text ──────────────────────────────────────────────────────────────────
  both(
    ".argo-table-list__row .title-text, .white-box__details-row, .top-bar__breadcrumbs, .sliding-panel__header strong, .popup-overlay .popup-container__body p",
    "color: var(--bh-ink);",
  ),
  both(".argo-table-list__head, .applications-list__entry, .argo-dropdown__content.is-menu ul li", "color: var(--bh-ink-dim);"),
  both(".argo-field, .argo-textarea", "color: var(--bh-ink);\nborder-color: var(--bh-rule-strong);"),

  // ── Crimson: primary actions, links, the active item (Argo CD's teal) ─────
  both("a, a:hover", "color: var(--bh-accent);"),
  both(".top-bar__title, .tabs__nav a.active, .tabs__nav.transparent a.active, .applications-list__view-type i.selected", "color: var(--bh-accent);"),
  // Plain buttons first: the variants below repaint the ones that have a fill.
  both(".argo-button, .argo-button--base-o, .argo-button--link, .argo-button--rectangle", "color: var(--bh-accent);"),
  both(
    ".argo-button--base, .argo-button--special, .argo-button--radius",
    "color: var(--bh-accent-ink);\nbackground-color: var(--bh-accent);",
  ),
  both(
    ".argo-button--base:not(.disabled):not([disabled]):hover, .argo-button--base:not(.disabled):not([disabled]):focus, .argo-button--special:not(.disabled):hover, .argo-button--radius:hover",
    "color: var(--bh-accent-ink);\nbackground: var(--bh-accent-hover) !important;",
  ),
  both(".argo-button--base-o, .argo-button--rectangle", "box-shadow: inset 0 0 0 1px var(--bh-accent);"),
  both(
    ".argo-button--base-o:not(.disabled):not([disabled]):hover, .argo-button--base-o:not(.disabled):not([disabled]):focus",
    "color: var(--bh-accent-ink);\nbackground-color: var(--bh-accent);",
  ),
  both(".argo-checkbox input:checked+span", "background-color: var(--bh-accent);\ncolor: var(--bh-accent-ink);"),
  both(".argo-checkbox-slide input:checked+span::before", "background-color: var(--bh-accent);"),
  both(".argo-field:focus, .argo-textarea:focus", "border-color: var(--bh-accent);"),
  both(".argo-field-container>.argo-field:focus+label.argo-label-placeholder", "color: var(--bh-accent);"),
  both(".application-resource-tree__node.active, .applications-tiles__selected", "border-color: var(--bh-accent);\nbox-shadow: 0 0 0 1px var(--bh-accent);"),

  // ── Shape: square, flat, the amber focus ring ─────────────────────────────
  `.layout *,\n.login *,\n.sliding-panel *,\n.popup-overlay * {\n  border-radius: 0 !important;\n}`,
  `:focus-visible {\n  outline: 2px solid var(--bh-focus) !important;\n  outline-offset: 2px;\n}`,

  // ── Sidebar: always on the dark ground, whichever the theme ───────────────
  `.sidebar {\n  background-color: ${sidebar.ground};\n  border-right: 1px solid ${sidebar.rule};\n}`,
  `.sidebar__nav-item,\n.sidebar__logo-container,\n.sidebar__collapse-button {\n  color: ${sidebar.inkDim};\n}`,
  `.sidebar__nav-item i,\n.sidebar__nav-item--active {\n  color: ${sidebar.ink};\n}`,
  `.sidebar__nav-item--active i {\n  color: ${sidebar.accent};\n}`,
  // The octopus, swapped for the crab, one pixel per pixel.
  `.sidebar__logo__character {\n  content: url("logo-dark.svg");\n  width: 26px !important;\n  height: 41px;\n  margin: 0 8px;\n  image-rendering: pixelated;\n}`,

  // ── Login page: the flow background and the brand's faces ─────────────────
  `.login {\n  background: var(--bh-page) url("background-light.svg") center / cover no-repeat;\n  font-family: "${fonts.text.family}", ${fonts.text.fallback};\n}`,
  `.theme-dark .login {\n  background-image: url("background-dark.svg");\n}`,
  `.login .argo__logo {\n  background-image: url("logo-light.svg");\n  image-rendering: pixelated;\n  height: 41vh;\n}`,
  `.theme-dark .login .argo__logo {\n  background-image: url("logo-dark.svg");\n}`,
  `.login__text {\n  font-family: "${fonts.display.family}", ${fonts.display.fallback};\n  font-size: 32px;\n  letter-spacing: 0.02em;\n  color: var(--bh-ink);\n}`,
  both(".login__box", "background-color: var(--bh-box);\ncolor: var(--bh-ink);\nborder-left: 1px solid var(--bh-rule-strong);"),
  both(".login__box h3, .login__box h4, .login__box h5", "color: var(--bh-ink);"),
  both(".login__more-row a, .login__saml-separator, .login__footer, .login__footer a, .login__footer .ver", "color: var(--bh-ink-dim);"),
  `.login__logo img.logo-image {\n  content: url("logo-light.svg");\n  width: 52px;\n  image-rendering: pixelated;\n}`,
  `.theme-dark .login__logo img.logo-image {\n  content: url("logo-dark.svg");\n}`,
  `.login .argo-button {\n  font-family: "${fonts.display.family}", ${fonts.display.fallback};\n  font-size: 16px;\n  letter-spacing: 0.06em;\n  text-transform: uppercase;\n}`,
];

/** The stylesheet ui.cssurl points at. */
export function renderArgoCss({ tokens, fonts }) {
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
  const sidebar = {
    ground: hex(d.groundSunk),
    rule: hex(d.ruleSoft),
    ink: hex(d.ink),
    inkDim: hex(d.inkDim),
    accent: hex(d.accent),
    lightPage: hex(tokens.light.groundSunk),
    darkPage: hex(d.groundSunk),
  };
  return `/* BatleHub for Argo CD. Generated by 3.custo/batlehub-theme; edit there and rebuild. */
${faces}

:root,
.theme-light {
${block(tokens.light)}
  color-scheme: light;
}
.theme-dark {
${block(tokens.dark)}
  color-scheme: dark;
}

${rules(fonts, sidebar).join("\n\n")}
`;
}
