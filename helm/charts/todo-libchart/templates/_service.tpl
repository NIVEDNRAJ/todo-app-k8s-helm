{{- define "todo-libchart.service.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.service) }}
    {{- with $root }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $val.serviceName | default (printf "%s-service" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
    {{- if $val.service.labels }}
    {{- toYaml $val.service.labels | nindent 4 }}
    {{- end }}
  {{- if $val.service.annotations }}
  annotations:
    {{- toYaml $val.service.annotations | nindent 4 }}
  {{- end }}
spec:
  type: {{ $val.service.type | default .Values.service.type | default "ClusterIP" }}
  ports:
    - port: {{ $val.service.port }}
      targetPort: {{ $val.service.targetPort | default $val.service.port }}
      protocol: {{ $val.service.protocol | default "TCP" }}
      name: {{ $val.service.portName | default "http" }}
  selector:
    {{- include "todo-libchart.selectorLabels" (dict "root" . "component" $val) | nindent 4 }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
