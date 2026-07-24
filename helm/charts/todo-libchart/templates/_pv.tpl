{{- define "todo-libchart.pv.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) ($val.persistence) ($val.persistence.enabled | default false) ($val.persistence.pvEnabled | default false) }}
    {{- with $root }}
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ $val.persistence.pvName | default (printf "%s-pv" $val.name) }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
spec:
  capacity:
    storage: {{ $val.persistence.size }}
  accessModes:
    - {{ $val.persistence.accessMode | default "ReadWriteOnce" }}
  persistentVolumeReclaimPolicy: {{ $val.persistence.reclaimPolicy | default "Retain" }}
  {{- if $val.persistence.storageClass }}
  storageClassName: {{ $val.persistence.storageClass | quote }}
  {{- end }}
  {{- if $val.persistence.hostPath }}
  hostPath:
    path: {{ $val.persistence.hostPath }}
  {{- else }}
  local:
    path: {{ $val.persistence.localPath | default "/mnt/data" }}
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - {{ $val.persistence.nodeName | default "minikube" }}
  {{- end }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
