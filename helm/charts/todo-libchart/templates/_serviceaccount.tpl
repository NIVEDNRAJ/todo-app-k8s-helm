{{- define "todo-libchart.serviceaccount.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.serviceAccount) ($val.serviceAccount.create | default false) }}
    {{- with $root }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $val.serviceAccount.name | default $val.name }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
  {{- if $val.serviceAccount.annotations }}
  annotations:
    {{- toYaml $val.serviceAccount.annotations | nindent 4 }}
  {{- end }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
