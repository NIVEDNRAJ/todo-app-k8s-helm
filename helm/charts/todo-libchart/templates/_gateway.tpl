{{- define "todo-libchart.gateway.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.gateway) ($val.gateway.enabled | default false) }}
    {{- with $root }}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: {{ $val.gateway.name | default (printf "%s-gateway" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
spec:
  gatewayClassName: {{ $val.gateway.className | default "gateway-api" }}
  listeners:
    {{- range $listener := $val.gateway.listeners }}
    - name: {{ $listener.name }}
      port: {{ $listener.port }}
      protocol: {{ $listener.protocol | default "HTTP" }}
      allowedRoutes:
        namespaces:
          from: {{ $listener.allowedNamespacesFrom | default "Same" }}
    {{- end }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
