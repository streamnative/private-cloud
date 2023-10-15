{{/*
Expand the name of the chart.
*/}}
{{- define "sn-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "sn-operator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "sn-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sn-operator.labels" -}}
helm.sh/chart: {{ include "sn-operator.chart" . }}
{{ include "sn-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sn-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sn-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "sn-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "sn-operator.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Expand to the namespace pulsar installs into.
*/}}
{{- define "sn-operator.namespace" -}}
{{- default .Release.Namespace .Values.namespace -}}
{{- end -}}


{{/*
Create the name of cluster role manager to use
*/}}
{{- define "sn-operator.clusterRoleManagerName" -}}
{{- printf "%s-%s" (include "sn-operator.fullname" .) "manager-cluster-role" -}}
{{- end -}}

{{/*
Create the name of role manager to use
*/}}
{{- define "sn-operator.roleLeaderElectionName" -}}
{{- printf "%s-%s" (include "sn-operator.fullname" .) "leader-election-role" -}}
{{- end -}}