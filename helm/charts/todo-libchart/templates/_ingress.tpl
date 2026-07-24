{{- define "todo-libchart.ingress.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.ingress) ($val.ingress.enabled | default false) }}
    {{- with $root }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $val.ingress.name | default (printf "%s-ingress" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
  {{- if $val.ingress.annotations }}
  annotations:
    {{- toYaml $val.ingress.annotations | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ $val.ingress.className | default .Values.ingress.className | quote }}
  rules:
    - http:
        paths:
          {{- range $path := $val.ingress.paths }}
          - path: {{ $path.path }}
            pathType: {{ $path.pathType | default "Prefix" }}
            backend:
              service:
                name: {{ $val.serviceName | default (printf "%s-service" $val.name) }}
                port:
                  number: {{ $val.service.port }}
          {{- end }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
