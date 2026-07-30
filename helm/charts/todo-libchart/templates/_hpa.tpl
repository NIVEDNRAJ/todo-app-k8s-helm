{{- define "todo-libchart.hpa.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.hpa) ($val.hpa.enabled | default false) }}
    {{- with $root }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $val.hpa.name | default (printf "%s-hpa" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ $val.deploymentName | default (printf "%s-deployment" $val.name) }}
  minReplicas: {{ $val.hpa.minReplicas | default 1 }}
  maxReplicas: {{ $val.hpa.maxReplicas | default 10 }}
  metrics:
    {{- if $val.hpa.metrics }}
    {{- toYaml $val.hpa.metrics | nindent 4 }}
    {{- else }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $val.hpa.targetCPUUtilizationPercentage | default 80 }}
    {{- end }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
