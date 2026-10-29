// Renders templates/home.tmpl (a Forgejo Go template) from the `home` config block.

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const row = (r) => `		<a class="bh-row" href="{{AppSubUrl}}${esc(r.href)}">
			<span class="bh-row-name">${esc(r.name)}</span>
			<span class="bh-row-note">${esc(r.note)}</span>
			<span class="bh-row-go" aria-hidden="true">-&gt;</span>
		</a>`;

const featuredSection = (f) => `	<section class="bh-sheet bh-featured" id="bh-featured" aria-labelledby="bh-featured-label" hidden>
		<h2 class="bh-section" id="bh-featured-label">${esc(f.heading)}</h2>
		<div id="bh-featured-rows"></div>
	</section>
`;

const featuredScript = (f) => `<script>
// Featured projects: every public repository carrying the topic below.
// On any failure the section simply stays hidden.
(function () {
	const TOPIC = ${JSON.stringify(f.topic)};
	const LIMIT = ${Number(f.limit)};
	const section = document.getElementById('bh-featured');
	const rows = document.getElementById('bh-featured-rows');
	if (!section || !rows) return;
	const span = function (cls, text) {
		const el = document.createElement('span');
		el.className = cls;
		el.textContent = text;
		return el;
	};
	const url = '{{AppSubUrl}}/api/v1/repos/search?topic=true&q=' + encodeURIComponent(TOPIC) +
		'&sort=updated&order=desc&limit=' + LIMIT;
	fetch(url, {headers: {Accept: 'application/json'}})
		.then(function (res) { return res.ok ? res.json() : null; })
		.then(function (body) {
			const repos = body && Array.isArray(body.data) ? body.data : [];
			if (!repos.length) return;
			for (const repo of repos) {
				const row = document.createElement('a');
				row.className = 'bh-row bh-resolve';
				row.href = '{{AppSubUrl}}/' + repo.full_name.split('/').map(encodeURIComponent).join('/');
				row.append(span('bh-row-name', repo.name));
				row.append(span('bh-row-note', repo.description || repo.full_name));
				const meta = [repo.owner && repo.owner.login, repo.language, repo.stars_count + ' ★'].filter(Boolean);
				row.append(span('bh-row-go bh-row-meta', meta.join(' · ')));
				rows.append(row);
			}
			section.hidden = false;
		})
		.catch(function () {});
})();
</script>
`;

/** `preview` renders plain HTML (no Go template actions) with sample featured rows. */
export function renderHome(home, { preview = false } = {}) {
  const title = home.title ? esc(home.title) : preview ? "APP_NAME" : "{{AppName}}";
  const signIn = `		<p class="bh-actions">
			<a class="ui primary button" href="{{AppSubUrl}}/user/login">${esc(home.signIn)}</a>
		</p>`;
  let featured = "";
  if (home.featured) {
    featured = featuredSection(home.featured);
    if (preview) {
      const sample = [
        ["sample-project", "A repository carrying the topic “" + home.featured.topic + "” shows up here.", "owner · Rust · 12 ★"],
        ["another-one", "Up to " + home.featured.limit + " rows, most recently updated first.", "owner · Go · 3 ★"],
      ];
      featured = featured
        .replace(" hidden>", ">")
        .replace(
          '<div id="bh-featured-rows"></div>',
          '<div id="bh-featured-rows">' +
            sample
              .map(([n, d, m]) => `<a class="bh-row" href="#"><span class="bh-row-name">${esc(n)}</span><span class="bh-row-note">${esc(d)}</span><span class="bh-row-go bh-row-meta">${esc(m)}</span></a>`)
              .join("") +
            "</div>",
        );
    }
  }
  const body = `<div role="main" aria-label="Home" class="page-content home bh-home">
	<section class="bh-specimen">
		<div class="bh-plate" aria-hidden="true"></div>
		<p class="bh-label">${esc(home.label)}</p>
		<h1 class="bh-display">${title}</h1>
		<p class="bh-caption">${esc(home.caption)}</p>
${preview ? signIn : `		{{if not .IsSigned}}\n${signIn}\n		{{end}}`}
	</section>
${featured}	<section class="bh-sheet" aria-labelledby="bh-browse-label">
		<h2 class="bh-section" id="bh-browse-label">${esc(home.browse.heading)}</h2>
${home.browse.rows.map(row).join("\n")}
	</section>
</div>
`;
  if (preview) return body.replaceAll("{{AppSubUrl}}", "#");
  return `{{template "base/head" .}}\n${body}${home.featured ? featuredScript(home.featured) : ""}{{template "base/footer" .}}\n`;
}
