{{- /*
  Access levels and add-ons for a Che user's namespace. Kept in a template
  rather than in values on purpose: what a level *means* changes with the
  chart, in review, never through a WeeboSiUser's values.

  The ClusterRoles are defined in
  2.argo/helm/che/hardening/templates/workspace-access-roles.yaml, except
  baseline's, which are Che's own (che-operator maintains them).
*/ -}}

{{- /* Ordered, lowest first: the order is what "floor" compares. */ -}}
{{- define "user-app.access.levelOrder" -}}
- baseline
- deploy
{{- end -}}

{{- define "user-app.access.levels" -}}
# What Che binds by default (CHE_INFRA_KUBERNETES_USER__CLUSTER__ROLES), and
# the floor: Che does not work on less.
baseline:
  - {{ .Values.cheNamespace }}-cheworkspaces-clusterrole
  - {{ .Values.cheNamespace }}-cheworkspaces-devworkspace-clusterrole
deploy:
  - {{ .Values.cheNamespace }}-cheworkspaces-clusterrole
  - {{ .Values.cheNamespace }}-cheworkspaces-devworkspace-clusterrole
  - weebo-che-deploy
{{- end -}}

{{- define "user-app.access.addons" -}}
port-forward:
  - weebo-che-port-forward
{{- end -}}

{{- /*
  The ClusterRoles this person gets, deduplicated and sorted: the higher of
  the team's floor and their own level, plus the team's add-ons and their own.
  A person asking for less than their team's floor is a refused render, not a
  silent bump: the two objects say opposite things.
*/ -}}
{{- define "user-app.access.clusterRoles" -}}
{{- $access := .Values.cheUser.access -}}
{{- $order := include "user-app.access.levelOrder" . | fromYamlArray -}}
{{- $levels := include "user-app.access.levels" . | fromYaml -}}
{{- $addons := include "user-app.access.addons" . | fromYaml -}}
{{- /*
  Former levels still accepted, mapped to their replacement. `min` is read as
  `baseline`: a WeeboSiTeam rendered before min was dropped keeps its member
  Applications rendering until the operator rewrites them.
*/ -}}
{{- $aliases := dict "min" "baseline" -}}
{{- $floor := required "cheUser.access.teamLevel is set by the team template" $access.teamLevel -}}
{{- $floor = get $aliases $floor | default $floor -}}
{{- if not (has $floor $order) -}}
{{- fail (printf "cheUser.access.teamLevel %q is not one of %v" $floor $order) -}}
{{- end -}}
{{- $level := $access.level | default $floor -}}
{{- $level = get $aliases $level | default $level -}}
{{- if not (has $level $order) -}}
{{- fail (printf "cheUser.access.level %q is not one of %v" $level $order) -}}
{{- end -}}
{{- $rank := dict -}}
{{- range $i, $l := $order }}{{ $_ := set $rank $l $i }}{{ end -}}
{{- if lt (get $rank $level | int) (get $rank $floor | int) -}}
{{- fail (printf "cheUser.access.level %q is below the team's floor %q" $level $floor) -}}
{{- end -}}
{{- $roles := get $levels $level -}}
{{- range concat ($access.addons | default list) ($access.extraAddons | default list) -}}
{{- if not (hasKey $addons .) -}}
{{- fail (printf "unknown access add-on %q, known: %v" . (keys $addons | sortAlpha)) -}}
{{- end -}}
{{- $roles = concat $roles (get $addons .) -}}
{{- end -}}
{{- $roles | uniq | sortAlpha | toYaml -}}
{{- end -}}
