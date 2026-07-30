{{- define "todo-libchart.pvc.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.persistence) ($val.persistence.enabled | default false) }}
    {{- with $root }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ $val.persistence.claimName | default (printf "%s-pvc" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
spec:
  accessModes:
    - {{ $val.persistence.accessMode | default "ReadWriteOnce" }}
  {{- if or $val.persistence.storageClass .Values.storageClass }}
  storageClassName: {{ $val.persistence.storageClass | default .Values.storageClass | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ $val.persistence.size | required (printf "Persistence size is required for component %s" $key) }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
