// Everything you are expected to edit lives in this file.
// `npm run build` turns it into dist/ (CSS, fonts, images, home template, deploy manifests).

export default {
  // Theme id: produces theme-<name>-{auto,dark,light}.css and /assets/{fonts,img}/<name>/.
  name: "batlehub",

  // Stock theme family each rendition imports and overrides ("forgejo" or "gitea").
  base: "forgejo",

  // Design tokens, one set per rendition, as OKLCH (copy-paste from tokens.css).
  // Out-of-gamut values are chroma-clamped to sRGB at build time.
  tokens: {
    dark: {
      ground: "oklch(0.07 0.018 18)",
      groundRaised: "oklch(0.155 0.022 18)",
      groundSunk: "oklch(0.045 0.014 18)",
      ink: "oklch(0.93 0.018 25)",
      inkDim: "oklch(0.62 0.045 30)",
      ruleSoft: "oklch(0.34 0.03 25)",
      ruleStrong: "oklch(0.52 0.06 25)",
      accent: "oklch(0.65 0.235 25)",
      accentInk: "oklch(0.10 0.02 18)",
      copper: "oklch(0.72 0.14 52)",
      focus: "oklch(0.85 0.16 85)",
      // Not in the BatleHub palette: a forge needs "added / passed".
      green: "oklch(0.74 0.13 150)",
    },
    light: {
      ground: "oklch(0.97 0.008 18)",
      groundRaised: "oklch(0.935 0.010 18)",
      groundSunk: "oklch(0.99 0.004 18)",
      ink: "oklch(0.20 0.022 20)",
      inkDim: "oklch(0.44 0.04 25)",
      ruleSoft: "oklch(0.80 0.02 25)",
      ruleStrong: "oklch(0.62 0.05 25)",
      accent: "oklch(0.52 0.21 25)",
      accentInk: "oklch(0.99 0.004 18)",
      copper: "oklch(0.50 0.12 52)",
      focus: "oklch(0.55 0.11 85)",
      green: "oklch(0.47 0.12 150)",
    },
  },

  // Minimum WCAG contrast per pair, checked for both renditions.
  // `npm run check` (and `build`) fails when a pair drops below its floor.
  contrast: [
    ["ink", "ground", 7],
    ["inkDim", "ground", 4.5],
    ["inkDim", "groundRaised", 4.5],
    ["accent", "ground", 4.5],
    ["accentInk", "accent", 4.5],
    ["copper", "ground", 4.5],
    ["green", "ground", 4.5],
    ["ruleStrong", "ground", 3],
    ["focus", "ground", 3],
  ],

  // Faces. Files are read from assets/fonts/<name>/.
  fonts: {
    display: { family: "Silkscreen", fallback: "monospace", files: [
      { file: "silkscreen-400.woff2", weight: "400" },
      { file: "silkscreen-700.woff2", weight: "700" },
    ] },
    text: { family: "JetBrains Mono", fallback: "ui-monospace, monospace", files: [
      { file: "jetbrainsmono-latin.woff2", weight: "100 800" },
    ] },
  },

  // The halftone plate behind the home page header: opacity per rendition,
  // and which token inks it.
  plate: {
    dark: { ink: "copper", opacity: 0.34, opacityNarrow: 0.26 },
    light: { ink: "ink", opacity: 0.2, opacityNarrow: 0.2 },
  },

  // Home page (templates/home.tmpl). Set `home: false` to keep Forgejo's own.
  home: {
    label: "Source forge",
    // null = use APP_NAME from app.ini
    title: null,
    caption:
      "Repositories, reviews, pipelines and packages, held in one place and served from your own ground. Every line here separates two real things.",
    signIn: "Sign in",

    // Featured projects: public repositories carrying `topic`, newest first.
    // Set `featured: false` to drop the section.
    featured: { heading: "Featured", topic: "featured", limit: 6 },

    // Static rows. `href` is relative to the instance root.
    browse: {
      heading: "Browse",
      rows: [
        { name: "Repositories", note: "Everything public on this instance, most recently updated first.", href: "/explore/repos" },
        { name: "Organizations", note: "Teams and the projects they own.", href: "/explore/organizations" },
        { name: "People", note: "Who commits here.", href: "/explore/users" },
        { name: "API", note: "The same forge, without the pages.", href: "/api/swagger" },
      ],
    },
  },

  // Deploy manifests written to dist/deploy/.
  deploy: {
    namespace: "forgejo",
    configMapName: "forgejo-theme-batlehub",
    customPath: "/data/gitea",
    defaultTheme: "batlehub-auto",
    // Themes kept selectable next to the generated ones.
    keepThemes: ["forgejo-auto", "forgejo-light", "forgejo-dark"],
    // Where the build also copies public/ + templates/ (plus a theme.yaml with the
    // [ui] settings), relative to this file. The weebo-si Forgejo chart builds its
    // ConfigMap from that copy, so it is committed. `null` to skip.
    chartDir: "../../2.argo/helm/forgejo/files/theme",
  },
};
