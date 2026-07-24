{{/*
Render merged labels or dictionary utilities if needed.
*/}}
{{- define "todo-libchart.util.mergeDicts" -}}
{{- $dest := index . 0 -}}
{{- $src := index . 1 -}}
{{- merge $dest $src | toYaml -}}
{{- end -}}
