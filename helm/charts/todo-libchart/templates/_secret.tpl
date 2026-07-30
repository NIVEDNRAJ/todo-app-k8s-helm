{{- define "todo-libchart.secret.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.secretEnabled | default false) }}
    {{- with $root }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ $val.secretName | default (printf "%s-secret" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
type: {{ $val.secretType | default "Opaque" }}
stringData:
  {{- include (printf "%s-secret-callback" $val.name) (dict "root" . "component" $val) | nindent 2 }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
