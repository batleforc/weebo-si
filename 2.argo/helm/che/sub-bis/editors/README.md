# House editors

One editor devfile per file, published to Che's dashboard through the
`weebo-editors-definitions` ConfigMap (`templates/custo/editor.yaml`). What is
offered is decided in `2.argo/helm/che/main/values.yaml`, under `che.editors`.

## Adding an IDE

1. Start from an editor definition, e.g. an upstream one:
   `kubectl exec -n eclipse-che deploy/che-dashboard -- curl -s 'http://localhost:8080/dashboard/api/editors/devfile?che-editor=che-incubator/che-code/latest'`
2. Save it here as `<name>.yaml` and give it its own identity in `metadata`:
   `attributes.publisher: weebo`, a `name`, an `attributes.version`. The
   editor id is `<publisher>/<name>/<version>`; two files must not share one.
3. Point every `image:` at angos (`registry.pkg.weebo.poc/<cache>/...`) or at
   `ghcr.io/batleforc/weebodevimage/...`. Anything else is refused by
   imagePolicy when the workspace starts, not when the editor is listed.
4. Add `<name>: true` under `che.editors.custom`. To make it the preselected
   editor, set `che.editors.default` to its id.

The render fails, rather than shipping something half done, when a file here
is not listed in `che.editors.custom`, when an entry switched on has no file,
or when `che.editors.default` is an editor the dashboard would not show.
