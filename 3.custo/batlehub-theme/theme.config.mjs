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

  // Error pages: the templates github.com/tarampampam/error-pages renders for the hosts
  // Traefik serves (dist/errors-{internal,external}.html, previews in dist/errors/).
  // Codes listed under `pages` get their own copy; any other code shows error-pages'
  // message and description. `scene` is what the crab is up to, one of src/scenes.mjs.
  // Set `errors: false` to skip.
  errors: {
    pages: {
      400: { label: "400 · Bad request", title: "That made no sense", scene: "garbled",
        caption: "The request arrived garbled. Check what was sent, then try again." },
      401: { label: "401 · Unauthorized", title: "Who goes there?", scene: "door",
        caption: "This door wants to know who you are. Sign in first." },
      403: { label: "403 · Forbidden", title: "Not past this line", scene: "gate",
        caption: "You are known here, but this is not yours to open." },
      // What the catch-all routes answer for a host nothing else serves.
      404: { label: "404 · Not found", title: "There is nothing to see here", scene: "lost",
        caption: "No page answers at this address. It may have moved, or it was never here." },
      408: { label: "408 · Request timeout", title: "Fell asleep waiting", scene: "sleep",
        caption: "The request took too long to arrive. Send it again." },
      410: { label: "410 · Gone", title: "Long gone", scene: "gone",
        caption: "Something lived here once. It has been removed for good." },
      413: { label: "413 · Payload too large", title: "That will not fit", scene: "box",
        caption: "What you sent is bigger than this server accepts." },
      418: { label: "418 · I'm a teapot", title: "Short and stout", scene: "coffee",
        caption: "This server is a teapot and will not brew coffee. The crab is making it anyway." },
      429: { label: "429 · Too many requests", title: "Slow down", scene: "rush",
        caption: "Too many requests in too little time. Wait a moment, then try again." },
      500: { label: "500 · Server error", title: "Something broke inside", scene: "smoke",
        caption: "The server hit an error it did not expect. Try again shortly; if it keeps happening, tell an admin." },
      502: { label: "502 · Bad gateway", title: "Knocked over", scene: "dazed",
        caption: "The service behind this address answered with nonsense, or not at all." },
      // What a host under maintenance answers (and a backend with no pod left to serve it).
      503: { label: "503 · Maintenance", title: "Back shortly", scene: "work",
        caption: "This service is down for planned work. Nothing is lost; try again in a few minutes." },
      504: { label: "504 · Gateway timeout", title: "Still waiting", scene: "wait",
        caption: "The service behind this address did not answer in time." },
    },
    scene: "dazed",
    // The internal variant (hosts under weebo.poc) lists these; the external one shows
    // the page head only, so nothing about the inside leaks out.
    internal: {
      heading: "Tools",
      links: [
        { name: "Forgejo", note: "Repositories, reviews, pipelines.", href: "https://git.weebo.poc" },
        { name: "BatleHub", note: "Packages and their releases.", href: "https://pkg.weebo.poc" },
        { name: "Registry", note: "Container images (angos).", href: "https://registry.pkg.weebo.poc" },
        { name: "Workspaces", note: "Eclipse Che dev environments.", href: "https://cde.dev.weebo.poc" },
        { name: "Argo CD", note: "What is deployed, and why not.", href: "https://argo.weebo.poc" },
        { name: "ClickStack", note: "Logs, traces, metrics.", href: "https://clickstack.weebo.poc" },
        { name: "Longhorn", note: "Volumes and backups.", href: "https://longhorn.weebo.poc" },
        { name: "OpenBao", note: "Secrets.", href: "https://vault.weebo.poc" },
        { name: "Authentik", note: "Accounts and sign-in.", href: "https://auth.weebo.poc" },
      ],
    },
  },

  // Authentik: the brand's custom CSS (colours, fonts, shapes), its logo / favicon /
  // flow background, and the copy and layout of the flows people see. Set
  // `authentik: false` to skip.
  authentik: {
    // Browser tab and the sidebar of the user / admin interfaces.
    title: "Weebo",
    // Applied to every flow below that does not set its own: stacked, content_left,
    // content_right, sidebar_left, sidebar_right, sidebar_left_frame_background,
    // sidebar_right_frame_background.
    layout: "sidebar_left",
    // The halftone dots behind the flows: which token inks them, per rendition.
    // Unset falls back to `plate` (the Forgejo home page's).
    plateInk: { dark: "accent" },
    // Built-in flows, by slug. Keeps %(app)s where Authentik substitutes the
    // application's name. device-code-flow is not here: auth/sub already owns it
    // (values.yaml, flows.deviceCode).
    flows: {
      "default-authentication-flow": { title: "Sign in to Weebo" },
      "default-source-authentication": { title: "Sign in to Weebo" },
      "default-source-enrollment": { title: "Pick a username" },
      "default-provider-authorization-explicit-consent": { title: "%(app)s wants to know who you are" },
      "default-provider-authorization-implicit-consent": { title: "On to %(app)s" },
      "default-provider-invalidation-flow": { title: "Signed out of %(app)s" },
      "default-password-change": { title: "Change your password" },
      "default-authenticator-totp-setup": { title: "Set up an authenticator app" },
      "default-authenticator-webauthn-setup": { title: "Register a security key" },
      "default-authenticator-static-setup": { title: "Your recovery codes" },
      "default-user-settings-flow": { title: "Your details" },
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
    // Where the build also copies errors-{internal,external}.html, for the error-pages
    // releases in the ingress chart. `null` to skip.
    errorsDir: "../../2.argo/helm/ingress/sub/files/error-pages",
    // Authentik. The files (fonts, logos, favicon, backgrounds) go to the auth chart,
    // which mounts them into the server under /web/dist/assets/<name>: Authentik
    // serves that at `authentikAssets`. The CSS and brand.yaml go to the auth-app
    // chart, which writes them into the AuthentikBrand and AuthentikFlow CRs.
    // `null` to skip either.
    authentikAssets: "/static/dist/assets/batlehub",
    authentikFilesDir: "../../2.argo/helm/auth/main/files/theme",
    authentikBrandDir: "../../2.argo/helm/auth/sub/files/brand",
  },
};
