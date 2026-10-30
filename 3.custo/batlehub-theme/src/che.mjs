// The BatleHub theme for the Eclipse Che dashboard: the files che-operator mounts over
// /public/dashboard/assets/branding (a Secret labelled che-dashboard-secret).
//
// The dashboard is PatternFly 6. index.html loads branding.css ahead of PatternFly's own
// sheets, so every rule here needs a more specific selector than the one it overrides:
// `html:root` beats PatternFly's `:root`, and `html:root.pf-v6-theme-dark` beats its
// `:root:where(.pf-v6-theme-dark)`. The dashboard sets that class itself, from the user's
// choice in its settings (light / dark / follow the device).
//
// The dashboard serves a precompressed `<file>.gz` when one sits next to the file it is
// asked for, and the image ships one for che-logo.svg and che-logo-text.svg: a file
// mounted under either name is never seen by a browser. The logo goes under its own name
// and product.json points at it.
import { hex, mix } from "./color.mjs";

export const LOGO_FILE = "batlehub-logo.svg";

// PatternFly's semantic tokens, the ones its components read, for one rendition.
export function cheVariables(t) {
  const hover = mix(t.accent, t.ink, 0.25);
  const v = [];
  const add = (k, val) => v.push([`--pf-t--global--${k}`, val]);

  // surfaces: the page on the sunk ground, cards and controls on the ground
  add("background--color--primary--default", hex(t.ground));
  add("background--color--primary--hover", hex(t.groundRaised));
  add("background--color--primary--clicked", hex(t.groundRaised));
  add("background--color--secondary--default", hex(t.groundSunk));
  add("background--color--secondary--hover", hex(t.groundRaised));
  add("background--color--secondary--clicked", hex(t.groundRaised));
  add("background--color--tertiary--default", hex(t.groundRaised));
  add("background--color--floating--default", hex(t.ground));
  add("background--color--floating--hover", hex(t.groundRaised));
  add("background--color--floating--clicked", hex(t.groundRaised));
  add("background--color--control--default", hex(t.ground));
  add("background--color--control--read-only", hex(t.groundRaised));
  add("background--color--action--plain--hover", hex(t.groundRaised));
  add("background--color--action--plain--clicked", hex(t.groundRaised));
  add("background--color--inverse--default", hex(t.ink));
  add("background--color--disabled--default", hex(t.groundRaised));

  // text and icons
  add("text--color--regular", hex(t.ink));
  add("text--color--subtle", hex(t.inkDim));
  add("text--color--placeholder", hex(t.inkDim));
  add("text--color--disabled", hex(t.ruleStrong));
  add("text--color--inverse", hex(t.ground));
  add("icon--color--regular", hex(t.ink));
  add("icon--color--subtle", hex(t.inkDim));
  add("icon--color--disabled", hex(t.ruleStrong));
  add("icon--color--inverse", hex(t.ground));

  // crimson: primary actions, links, the active item
  for (const [state, c] of [["default", t.accent], ["hover", hover], ["clicked", hover]]) {
    add(`color--brand--${state}`, hex(c));
    add(`text--color--brand--${state}`, hex(c));
    add(`icon--color--brand--${state}`, hex(c));
    add(`border--color--brand--${state}`, hex(c));
    add(`text--color--on-brand--${state}`, hex(t.accentInk));
    add(`icon--color--on-brand--${state}`, hex(t.accentInk));
  }
  add("text--color--link--default", hex(t.accent));
  add("text--color--link--hover", hex(hover));
  add("text--color--link--visited", hex(t.accent));

  // rules
  add("border--color--default", hex(t.ruleSoft));
  add("border--color--hover", hex(t.ruleStrong));
  add("border--color--clicked", hex(t.accent));
  add("border--color--on-secondary", hex(t.ruleSoft));
  add("border--color--disabled", hex(t.ruleSoft));
  add("focus-ring--color--default", hex(t.focus));

  // state: crimson = refused, copper = waiting, green = passed. Info stays PatternFly's.
  for (const [status, c] of [["danger", t.accent], ["warning", t.copper], ["success", t.green]]) {
    add(`color--status--${status}--default`, hex(c));
    add(`color--status--${status}--hover`, hex(mix(c, t.ink, 0.25)));
    add(`color--status--${status}--clicked`, hex(mix(c, t.ink, 0.25)));
    for (const part of ["text", "icon", "border"]) add(`${part}--color--status--${status}--default`, hex(c));
  }
  return v;
}

// The same in both renditions: square corners, flat at rest.
const SHAPE = [
  ...["tiny", "small", "medium", "large"].map((s) => [`--pf-t--global--border--radius--${s}`, "0"]),
  ...["sm", "md", "lg"].map((s) => [`--pf-t--global--box-shadow--${s}`, "none"]),
];

// The page loader, which index.html shows before the dashboard (and its theme class) is
// up: on the device's ground. Its layout is the dashboard's own branding.css, kept.
const loader = (tokens) => `
.main-page-loader {
  background-color: ${hex(tokens.light.groundSunk)};
  color: ${hex(tokens.light.ink)};
  font-family: Helvetica, Arial, sans-serif;
  font-size: 24px;
  inset: 0;
  margin: auto;
  position: absolute;
  z-index: 80;
}
@media (prefers-color-scheme: dark) {
  .main-page-loader {
    background-color: ${hex(tokens.dark.groundSunk)};
    color: ${hex(tokens.dark.ink)};
  }
}
.main-page-loader .ide-page-loader-content {
  align-items: center;
  display: flex;
  flex-direction: column;
  gap: 20px;
  inset: 0;
  justify-content: center;
  position: absolute;
}
.main-page-loader .ide-page-loader-content img {
  animation: opacity 2s ease-in-out infinite;
  image-rendering: pixelated;
  max-height: 140px;
  max-width: 140px;
  object-fit: contain;
}
@keyframes opacity {
  0%, to { opacity: 0; }
  50% { opacity: 1; }
}`;

const rules = `
/* Floats are a 1px frame, not a shadow. */
.pf-v6-c-menu,
.pf-v6-c-modal-box,
.pf-v6-c-popover,
.pf-v6-c-tooltip__content,
.pf-v6-c-alert {
  border: 1px solid var(--pf-t--global--border--color--hover);
}
/* The masthead logo is pixel art: one pixel per pixel, not stretched to 36px. */
.pf-v6-c-masthead .pf-v6-c-brand {
  height: 41px !important;
  width: auto;
  image-rendering: pixelated;
}`;

/** branding.css */
export function renderCheCss({ tokens }) {
  const block = (r) => [...cheVariables(tokens[r]), ...SHAPE, ["color-scheme", r]]
    .map(([k, val]) => `  ${k}: ${val};`)
    .join("\n");
  return `/* BatleHub for the Eclipse Che dashboard. Generated by 3.custo/batlehub-theme; edit there and rebuild. */
html:root {
${block("light")}
}
html:root.pf-v6-theme-dark {
${block("dark")}
}
${loader(tokens)}
${rules}
`;
}

/**
 * The masthead logo. The dashboard fills every `.outer-fill` shape with the theme's
 * regular text colour, so one file serves both renditions.
 */
export function renderCheLogo(logoSvg) {
  const out = logoSvg.replace(/<path fill="[^"]*"/g, '<path class="outer-fill" fill="currentColor"');
  if (!out.includes('class="outer-fill"')) throw new Error("che: the logo has no <path fill=…> to recolour");
  return out;
}

/**
 * product.json. The dashboard deep-merges it over its defaults, arrays by index: `links`
 * replaces as many of the three default links as it lists, so it lists three.
 */
export function renderProductJson(che) {
  if (che.links.length < 3) throw new Error("che.links: list three, or the dashboard keeps its own past the last one");
  return JSON.stringify({ title: che.title, name: che.name, logoFile: LOGO_FILE, links: che.links }, null, 2) + "\n";
}

/** manifest.json, for "install as an app". */
export function renderManifest(che, tokens) {
  return JSON.stringify(
    {
      short_name: che.shortName,
      name: che.name,
      icons: [{ src: "./loader.svg", sizes: "any" }],
      start_url: "../..",
      display: "standalone",
      theme_color: hex(tokens.dark.groundSunk),
      background_color: hex(tokens.light.groundSunk),
      scope: "../..",
    },
    null,
    2,
  ) + "\n";
}

/** A one-image .ico around a PNG (Vista and later read PNG entries as they are). */
export function icoFromPng(png) {
  if (png.readUInt32BE(0) !== 0x89504e47) throw new Error("icoFromPng: not a PNG");
  const width = png.readUInt32BE(16);
  const height = png.readUInt32BE(20);
  if (width > 256 || height > 256) throw new Error(`icoFromPng: ${width}x${height} is over 256px`);
  const head = Buffer.alloc(22);
  head.writeUInt16LE(0, 0); // reserved
  head.writeUInt16LE(1, 2); // type: icon
  head.writeUInt16LE(1, 4); // one image
  head.writeUInt8(width % 256, 6); // 0 means 256
  head.writeUInt8(height % 256, 7);
  head.writeUInt8(0, 8); // no palette
  head.writeUInt8(0, 9);
  head.writeUInt16LE(1, 10); // colour planes
  head.writeUInt16LE(32, 12); // bits per pixel
  head.writeUInt32LE(png.length, 14);
  head.writeUInt32LE(22, 18); // offset of the image
  return Buffer.concat([head, png]);
}
