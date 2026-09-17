// Ajoute un bandeau "documentation archivee" dans les pages deja construites de
// l'ancienne doc. L'injection se fait apres le build parce que les sources sont
// figees dans un tag git: rien n'est modifie en amont.
//
// Le bandeau doit etre `position: fixed` et declarer sa hauteur dans
// --vp-layout-top-height: c'est le mecanisme prevu par VitePress pour ce cas
// (12 regles de son CSS s'en servent, dont `.VPNav { top: ... }` et la sidebar).
// Sans ca, la nav fixe passe par-dessus le bandeau et aucune place ne lui est
// reservee -- il reste visible uniquement la ou rien ne le recouvre.
import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [dist] = process.argv.slice(2);

if (!dist) {
  console.error('usage: inject-archive-banner.mjs <dist>');
  process.exit(1);
}

const MARKER = 'data-weebo-archive-banner';

// Les couleurs viennent des variables VitePress: le bandeau suit le theme clair
// comme le theme sombre sans feuille de style supplementaire.
const STYLE = `<style ${MARKER}>
:root{--vp-layout-top-height:40px}
.weebo-archive-banner{position:fixed;top:0;left:0;right:0;z-index:var(--vp-z-index-layout-top,40);box-sizing:border-box;display:flex;flex-wrap:wrap;align-items:center;justify-content:center;gap:.125rem .75rem;height:var(--vp-layout-top-height);padding:.25rem 1rem;overflow:hidden;background-color:var(--vp-c-warning-soft);color:var(--vp-c-text-1);font-size:.8125rem;line-height:1.35;text-align:center}
.weebo-archive-banner a{font-weight:600;color:var(--vp-c-brand-1);text-decoration:underline;text-underline-offset:2px;white-space:nowrap}
.weebo-archive-banner .weebo-short{display:none}
/* Sous 768px la phrase longue tiendrait sur trois lignes: version courte, et
   la hauteur reservee suit (deux lignes au lieu d'une). */
@media (max-width:767px){
:root{--vp-layout-top-height:52px}
.weebo-archive-banner{font-size:.75rem}
.weebo-archive-banner .weebo-long{display:none}
.weebo-archive-banner .weebo-short{display:inline}
}
</style>`;

const BANNER = `<div class="weebo-archive-banner" ${MARKER}>`
  + `<span class="weebo-long">Vous lisez la documentation archiv&eacute;e (saisons 1 &amp; 2), fig&eacute;e et conserv&eacute;e pour les anciens liens.</span>`
  + `<span class="weebo-short">Documentation archiv&eacute;e (saisons 1 &amp; 2).</span>`
  + `<a href="/weebo-si/">Aller &agrave; la doc actuelle &rarr;</a>`
  + `</div>`;

function htmlFiles(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) return htmlFiles(full);
    return full.endsWith('.html') ? [full] : [];
  });
}

let patched = 0;

for (const file of htmlFiles(dist)) {
  const html = readFileSync(file, 'utf8');
  if (html.includes(MARKER)) continue;
  if (!html.includes('</head>') || !html.includes('<body>')) {
    console.warn(`structure inattendue, page ignoree: ${file}`);
    continue;
  }
  writeFileSync(
    file,
    html
      // En dernier dans le head: redefinit --vp-layout-top-height apres les
      // feuilles de style du theme.
      .replace('</head>', `${STYLE}\n</head>`)
      // Avant <div id="app">: Vue s'hydrate dans #app et ignore ce qui le precede.
      .replace('<body>', `<body>${BANNER}`),
  );
  patched += 1;
}

console.log(`bandeau d'archive injecte dans ${patched} page(s) de ${dist}`);
