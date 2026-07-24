{{- define "todo-libchart.pdb.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.pdb) ($val.pdb.enabled | default false) }}
    {{- with $root }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ $val.pdb.name | default (printf "%s-pdb" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
spec:
  {{- if $val.pdb.minAvailable }}
  minAvailable: {{ $val.pdb.minAvailable }}
  {{- end }}
  {{- if $val.pdb.maxUnavailable }}
  maxUnavailable: {{ $val.pdb.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "todo-libchart.selectorLabels" (dict "root" . "component" $val) | nindent 6 }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
