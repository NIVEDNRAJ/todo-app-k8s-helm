{{- define "todo-libchart.deployment.tpl" -}}
{{- $root := . -}}
{{- range $key, $val := .Values.components }}
  {{- if and ($val.enabled | default false) (eq ($val.kind | default "Deployment") "Deployment") }}
    {{- with $root }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $val.deploymentName | default (printf "%s-deployment" $val.name) }}
  namespace: {{ .Values.namespace | default .Release.Namespace }}
  labels:
    {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 4 }}
    {{- if $val.labels }}
    {{- toYaml $val.labels | nindent 4 }}
    {{- end }}
  {{- if $val.annotations }}
  annotations:
    {{- toYaml $val.annotations | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ $val.replicaCount | default 1 }}
  selector:
    matchLabels:
      {{- include "todo-libchart.selectorLabels" (dict "root" . "component" $val) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "todo-libchart.labels" (dict "root" . "component" $val) | nindent 8 }}
        {{- if $val.labels }}
        {{- toYaml $val.labels | nindent 8 }}
        {{- end }}
      {{- if or $val.podAnnotations $val.annotations }}
      annotations:
        {{- if $val.podAnnotations }}
        {{- toYaml $val.podAnnotations | nindent 8 }}
        {{- end }}
        {{- if and $val.annotations (not $val.podAnnotations) }}
        {{- toYaml $val.annotations | nindent 8 }}
        {{- end }}
      {{- end }}
    spec:
      {{- if $val.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml $val.imagePullSecrets | nindent 8 }}
      {{- else if .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.imagePullSecrets | nindent 8 }}
      {{- end }}
      {{- if $val.serviceAccountName }}
      serviceAccountName: {{ $val.serviceAccountName }}
      {{- else if $val.serviceAccount }}
      serviceAccountName: {{ $val.serviceAccount.name | default $val.name }}
      {{- end }}
      {{- if $val.securityContext }}
      securityContext:
        {{- toYaml $val.securityContext | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ $val.containerName | default $key }}
          image: "{{ $val.image.repository }}:{{ $val.image.tag | default "latest" }}"
          {{- if $val.image.pullPolicy }}
          imagePullPolicy: {{ $val.image.pullPolicy }}
          {{- end }}
          {{- if $val.command }}
          command:
            {{- toYaml $val.command | nindent 12 }}
          {{- end }}
          {{- if $val.args }}
          args:
            {{- toYaml $val.args | nindent 12 }}
          {{- end }}
          {{- if $val.service }}
          ports:
            - containerPort: {{ $val.service.port }}
              name: {{ $val.service.containerPortName | default $val.service.portName | default "http" }}
          {{- end }}
          {{- if $val.envVars }}
          env:
            {{- range $env := $val.envVars }}
            - name: {{ $env.name }}
              {{- if hasKey $env "value" }}
              value: {{ tpl (toString $env.value) $ | quote }}
              {{- else if $env.valueFrom }}
              valueFrom:
                {{- toYaml $env.valueFrom | nindent 16 }}
              {{- end }}
            {{- end }}
          {{- end }}
          {{- if $val.envFrom }}
          envFrom:
            {{- toYaml $val.envFrom | nindent 12 }}
          {{- end }}
          {{- if $val.resources }}
          resources:
            {{- toYaml $val.resources | nindent 12 }}
          {{- end }}
          {{- if $val.probes }}
            {{- if $val.probes.startup }}
          startupProbe:
            {{- tpl (toYaml $val.probes.startup) $ | nindent 12 }}
            {{- end }}
            {{- if $val.probes.liveness }}
          livenessProbe:
            {{- tpl (toYaml $val.probes.liveness) $ | nindent 12 }}
            {{- end }}
            {{- if $val.probes.readiness }}
          readinessProbe:
            {{- tpl (toYaml $val.probes.readiness) $ | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- if $val.volumeMounts }}
          volumeMounts:
            {{- tpl (toYaml $val.volumeMounts) $ | nindent 12 }}
          {{- end }}
      {{- if $val.volumes }}
      volumes:
        {{- tpl (toYaml $val.volumes) $ | nindent 8 }}
      {{- end }}
      {{- if $val.nodeSelector }}
      nodeSelector:
        {{- toYaml $val.nodeSelector | nindent 8 }}
      {{- end }}
      {{- if $val.affinity }}
      affinity:
        {{- toYaml $val.affinity | nindent 8 }}
      {{- end }}
      {{- if $val.tolerations }}
      tolerations:
        {{- toYaml $val.tolerations | nindent 8 }}
      {{- end }}
---
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
