// Ajoute un bandeau "documentation archivee" dans les pages deja construites de
// l'ancienne doc. L'injection se fait apres le build parce que les sources sont
// figees dans un tag git: rien n'est modifie en amont.
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
const BANNER = `<div ${MARKER} style="display:flex;flex-wrap:wrap;gap:.5rem 1rem;align-items:center;justify-content:center;padding:.5rem 1.5rem;background-color:var(--vp-c-warning-soft);color:var(--vp-c-text-1);font-size:.875rem;line-height:1.4;text-align:center">`
  + `<span>Vous lisez la documentation archiv&eacute;e (saisons 1 &amp; 2), fig&eacute;e et conserv&eacute;e pour les anciens liens.</span>`
  + `<a href="/weebo-si/" style="font-weight:600;color:var(--vp-c-brand-1);text-decoration:underline;text-underline-offset:2px;white-space:nowrap">Aller &agrave; la doc actuelle &rarr;</a>`
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
  if (html.includes(MARKER) || !html.includes('<body>')) continue;
  // Avant <div id="app">: Vue s'hydrate dans #app et ignore ce qui le precede.
  writeFileSync(file, html.replace('<body>', `<body>${BANNER}`));
  patched += 1;
}

console.log(`bandeau d'archive injecte dans ${patched} page(s) de ${dist}`);
