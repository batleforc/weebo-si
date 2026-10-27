# forgejo-theme-batlehub

The BatleHub design system as a Forgejo theme. Tokens and copy go in; CSS, fonts, images,
the home page template and the deploy manifests come out. Node >= 20, no dependencies.

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
- `home.tmpl` relies on `base/head`, `base/footer`, `AppName`, `AppSubUrl`, `.IsSigned`;
  re-check it after a major Forgejo upgrade.
