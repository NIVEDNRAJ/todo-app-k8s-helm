{{- define "todo-libchart.configmap.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.configMapEnabled | default false) }}
    {{- with $root }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $val.configMapName | default (printf "%s-configmap" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
data:
  {{- include (printf "%s-configmap" $val.name) (dict "root" . "component" $val) | nindent 2 }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
