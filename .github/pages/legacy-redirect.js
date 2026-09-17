// Injecte dans le 404.html de GitHub Pages: les anciennes URLs de la doc
// VitePress (servies a la racine jusqu'a la saison 2) pointent desormais vers
// l'archive sous /weebo-si/v2/. Tout le reste retombe sur la SPA, qui affiche
// sa propre page "not found".
(function () {
  var base = '/weebo-si/';
  var path = location.pathname;
  if (path.indexOf(base) !== 0) return;

  var rest = path.slice(base.length);
  // Deja dans l'archive: c'est un vrai 404, on ne boucle pas.
  if (rest.indexOf('v2/') === 0) return;

  // Racines de premier niveau de l'ancienne doc, plus ses assets public/.
  var legacyRoots = [
    '0.communication/',
    '0.introduction/',
    '0.projects/',
    '0.setup/',
    '0.us/',
    '1.Kubevirt/',
    '1.Proxmox/',
    'demo/',
    '1.infrastructure/',
    'yaml-asset/',
  ];

  var isLegacy = /\.html$/.test(rest);
  for (var i = 0; i < legacyRoots.length && !isLegacy; i++) {
    isLegacy = rest.indexOf(legacyRoots[i]) === 0;
  }

  if (isLegacy) {
    location.replace(base + 'v2/' + rest + location.search + location.hash);
  }
})();
