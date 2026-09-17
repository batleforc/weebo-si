// Construit le 404.html du site Pages: le shell SPA de la doc courante, avec la
// redirection des anciennes URLs injectee avant le boot de l'application.
import { readFileSync, writeFileSync } from 'node:fs';

const [fallback, shim, out] = process.argv.slice(2);

if (!fallback || !shim || !out) {
  console.error('usage: make-404.mjs <spa-fallback.html> <shim.js> <404.html>');
  process.exit(1);
}

const html = readFileSync(fallback, 'utf8');
const js = readFileSync(shim, 'utf8');

if (!html.includes('<head>')) {
  throw new Error(`pas de <head> dans ${fallback}, la redirection ne peut pas etre injectee`);
}

writeFileSync(out, html.replace('<head>', `<head>\n<script>\n${js}</script>`));
console.log(`404.html ecrit dans ${out}`);
