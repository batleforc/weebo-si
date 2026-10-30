# batlehub-theme

The BatleHub design system for Forgejo, the error pages, Authentik, the Eclipse Che
dashboard and Argo CD. Tokens and copy go in; CSS, fonts, images, the Forgejo home page,
the error-pages templates, the Authentik brand, the Che branding, the Argo CD stylesheet
and the deploy manifests come out. Node >= 20, no dependencies.

```
npm run build    # contrast check, then write dist/
npm run check    # contrast report only
npm run watch    # rebuild on change
npm test
```

Open `dist/preview.html` after a build to see both renditions (home page, palette with
contrast ratios, a few controls) without a running Forgejo.

## What to edit

| To change…                                        | Edit                         |
| ------------------------------------------------- | ---------------------------- |
| Colours, contrast floors, fonts, theme name       | `theme.config.mjs`           |
| Home page copy, rows, featured topic / limit      | `theme.config.mjs` → `home`  |
| Error pages: copy, crab scene, internal tools     | `theme.config.mjs` → `errors`|
| Namespace, ConfigMap name, default theme, chart  | `theme.config.mjs` → `deploy`|
| Logo, favicon (replace Forgejo's own)             | `assets/img/`                |
| Navbar logo per rendition, halftone plate         | `assets/img/theme/`          |
| Font files                                        | `assets/fonts/`              |
| Which Forgejo variable a token feeds              | `src/variables.mjs`          |
| Component rules (radius, focus ring, navbar…)     | `src/rules.css`              |
| Home page and error page rules                    | `src/home.css`               |
| Crab scenes: props as ASCII sprites, positions    | `src/scenes.mjs`             |
| Error page base and crab animations               | `src/errors.css`             |
| Home page markup                                  | `src/home.mjs`               |
| Error page markup                                 | `src/errors.mjs`             |
| Authentik: brand title, flow titles and layout    | `theme.config.mjs` → `authentik` |
| Authentik: which PatternFly variable a token feeds, component rules, flow background | `src/authentik.mjs` |
| Che: product name, help-menu links                | `theme.config.mjs` → `che`   |
| Che: which PatternFly 6 token a token feeds, logo, loader, favicon | `src/che.mjs` |
| Argo CD: the rules it overrides, sidebar, login page | `src/argocd.mjs`          |

Colours are written as OKLCH and converted to sRGB hex at build time; a value outside the
sRGB gamut has its chroma reduced until it fits. The build fails if a pair listed under
`contrast` drops below its floor in either rendition.

The PNGs in `assets/img/` (`logo.png`, `favicon.png`, `apple-touch-icon.png`) are plain
source files: re-export them yourself if you change the logo.

## Output

```
dist/
  public/assets/css/theme-<name>-{auto,dark,light}.css
  public/assets/fonts/<name>/…
  public/assets/img/…                 logo + favicon overrides
  public/assets/img/<name>/…          per-rendition logos, halftone plate
  templates/home.tmpl
  kustomization.yaml                  ConfigMap generator for everything above
  values.forgejo.yaml                 Helm values: [ui] themes, volume, mounts
  preview.html
  errors-{internal,external}.html     error-pages templates (Go text/template, self-contained)
  errors/<variant>-{404,503,502}.html the same, rendered, to open in a browser

<deploy.chartDir>/                    (2.argo/helm/forgejo/files/theme, committed)
  public/…  templates/…               same files as dist/
  theme.yaml                          name, THEMES, DEFAULT_THEME

<deploy.errorsDir>/errors-*.html      (2.argo/helm/ingress/sub/files/error-pages, committed)

dist/authentik/
  files/fonts/…  logo-{light,dark}.svg  favicon.svg  background-{light,dark}.svg
  brand/custom.css                    the brand's custom CSS
  brand/brand.yaml                    title, logo / favicon / background paths, flow copy

<deploy.authentikFilesDir>/           (2.argo/helm/auth/main/files/theme, committed)
<deploy.authentikBrandDir>/           (2.argo/helm/auth/sub/files/brand, committed)

dist/che/                             branding.css  product.json  manifest.json
                                      batlehub-logo.svg  loader.svg  favicon.ico
<deploy.cheDir>/                      (2.argo/helm/che/sub/files/branding, committed)

dist/argocd/                          batlehub.css, and next to it the logos, login
                                      backgrounds and fonts it names
<deploy.argocdDir>/                   (2.argo/app/files/argocd-theme, committed)
```

Each rendition imports the stock `theme-<base>-{dark,light}.css` and overrides it, so any
variable not mapped here falls back to Forgejo's.

## Deploy

weebo-si: nothing to do but build and commit. `npm run build` also writes the files into
`deploy.chartDir`, the `2.argo/helm/forgejo` chart turns them into the `forgejo-theme`
ConfigMap, mounts it, sets `[ui]` from `theme.yaml` and rolls the pod when a checksum of
the files changes. Commit the source and the chart copy together; the `Forgejo theme`
workflow fails when they disagree. `deploy.namespace`, `configMapName` and `customPath`
only feed the standalone manifests below.

Manual: copy `dist/public` and `dist/templates` into `$FORGEJO_CUSTOM/`, then set
`[ui] THEMES` / `DEFAULT_THEME` as in `values.forgejo.yaml` and restart.

Kubernetes, any other cluster: `kubectl apply -k dist/` (or point an ArgoCD source at it), merge
`values.forgejo.yaml` into the chart values, then `kubectl rollout restart` the Forgejo
workload — `subPath` mounts do not pick up ConfigMap updates, and templates are loaded at
start-up.

Notes:

- The two mounts cover `<customPath>/public` and `<customPath>/templates`; anything already
  there on the volume is hidden.
- The home page is styled by these themes only: keep one of them as `DEFAULT_THEME`.
- Featured projects are fetched client-side from `/api/v1/repos/search`; the section stays
  hidden when nothing carries the topic or the API is not readable anonymously.
- Error pages: [error-pages](https://github.com/tarampampam/error-pages) renders them for
  every host behind Traefik, in two variants: `internal` (hosts under the ingress chart's
  `errorPages.internalDomain`, behind vpn-only, lists `errors.internal.links`) and `external`
  (everything else, page head only). 404 and 503 have their own copy ("There is nothing to
  see here" for hosts no route claims, "Maintenance" for hosts listed in
  `errorPages.maintenance.hosts`); other codes show error-pages' message. Each page has a
  crab scene (`src/scenes.mjs`, one per code: lost, door, coffee…), CSS-only, still under
  reduced motion. Fonts and sprites are inlined, so a page loads nothing (~85 KB). Wiring:
  `2.argo/helm/ingress/sub/templates/error-pages`.
- Authentik: the files are mounted on the server at `/web/dist/assets/batlehub` (auth/main,
  `templates/authentik/theme.yaml`) and served as `deploy.authentikAssets`; the brand
  points its logo and background at `…-%(theme)s.svg`, which Authentik resolves to the
  light or dark file. `custom.css` becomes the brand's `brandingCustomCss`, which Authentik
  puts in `<head>` and in every component's shadow root, ahead of its own layered styles. It
  reaches `<head>` HTML-escaped, so the build refuses `<`, `>` and `&` in it: write
  descendant selectors, not child ones. The colours go through PatternFly's
  `--pf-global--*` variables and Authentik's `--ak-*` ones; re-check them after a major
  Authentik upgrade. A session in safe mode (`?safe_mode`) drops the CSS, which is the way
  back in if it ever hides the form.
- Che: the files become the `che-dashboard-customization` Secret (`2.argo/helm/che/sub`,
  `templates/branding.yaml`), which che-operator mounts file by file over the dashboard's
  `/public/dashboard/assets/branding`. Those subPath mounts never reload, so the CheCluster
  carries a checksum of the files in the dashboard's env: a new build rolls it. Three traps
  of the dashboard: `branding.css` loads *before* PatternFly (hence `html:root` and
  `html:root.pf-v6-theme-dark`), a file with a `.gz` next to it in the image is served from
  the `.gz` (hence `batlehub-logo.svg`, not `che-logo.svg`), and product.json is deep-merged
  over the defaults, arrays by index (hence three links). The logo's shapes carry
  `outer-fill`, which the dashboard paints in the theme's text colour. Re-check the
  `--pf-t--global--*` names after a PatternFly major in the dashboard.
- Argo CD: the files become `argocd-styles-cm` (`2.argo/app`, `templates/argocd-theme.yaml`),
  which the argo-cd chart mounts at `/shared/app/custom`; `ui.cssurl: ./custom/batlehub.css`
  is set in `1.pulu-conf` (`task puluconf:up`). Argo CD has no colour variables: the sheet
  repaints its main surfaces rule by rule, each written plain and under `.theme-dark`. A
  class renamed by an upgrade falls back to Argo CD's look.
- `home.tmpl` relies on `base/head`, `base/footer`, `AppName`, `AppSubUrl`, `.IsSigned`;
  re-check it after a major Forgejo upgrade.
