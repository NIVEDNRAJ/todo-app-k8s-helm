{{/*
Expand the name of the chart.
*/}}
{{- define "todo-libchart.name" -}}
{{- default .root.Chart.Name .root.Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "todo-libchart.fullname" -}}
{{- if .root.Values.fullnameOverride -}}
{{- .root.Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .root.Chart.Name .root.Values.nameOverride -}}
{{- if contains $name .root.Release.Name -}}
{{- .root.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .root.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "todo-libchart.chart" -}}
{{- printf "%s-%s" .root.Chart.Name .root.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Common labels to be applied to all resources.
*/}}
{{- define "todo-libchart.labels" -}}
helm.sh/chart: {{ include "todo-libchart.chart" . }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
{{- if .root.Values.commonLabels }}
{{ toYaml .root.Values.commonLabels }}
{{- end }}
{{- if .component }}
app: {{ .component.name }}
{{- end -}}
{{- end }}

{{/*
Selector labels for components.
*/}}
{{- define "todo-libchart.selectorLabels" -}}
{{- if .component -}}
app: {{ .component.name }}
{{- end -}}
{{- end }}
