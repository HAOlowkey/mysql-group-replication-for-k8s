{{/* vim: set filetype=mustache: */}}

{{- define "mysql.fullname" -}}
{{- include "common.names.fullname" . -}}
{{- end -}}

{{/*
Return the proper mysql image name
*/}}
{{- define "mysql.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the mysql proper Docker Image Registry Secret Names
*/}}
{{- define "mysql.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image) "global" .Values.global) }}
{{- end -}}

{{- define "proxysql.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "proxysql" .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper proxysql image name
*/}}
{{- define "proxysql.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.proxysql.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proxysql proper Docker Image Registry Secret Names
*/}}
{{- define "proxysql.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.proxysql.image) "global" .Values.global) }}
{{- end -}}

{{- define "mysql.auth.root.password" -}}
{{ default "Root@123!" .Values.auth.rootpassword | b64enc | quote }}
{{- end -}}
{{- define "mysql.auth.replication.username" -}}
{{ default "replicator" .Values.auth.replicationUser | b64enc | quote }}
{{- end -}}
{{- define "mysql.auth.replication.password" -}}
{{ default "Repl@123!" .Values.auth.replicationPassword | b64enc | quote }}
{{- end -}}
{{- define "mysql.auth.username" -}}
{{ default "abc" .Values.auth.username | b64enc | quote }}
{{- end -}}
{{- define "mysql.auth.password" -}}
{{ default "Abc@123!" .Values.auth.password | b64enc | quote }}
{{- end -}}
{{- define "proxysql.auth.monitor.username" -}}
{{ default "monitor" .Values.proxysql.auth.monitorUser | b64enc | quote }}
{{- end -}}
{{- define "proxysql.auth.monitor.password" -}}
{{ default "Monitor@123!" .Values.proxysql.auth.monitorPassword | b64enc | quote }}
{{- end -}}
{{- define "proxysql.auth.admin.username" -}}
{{ default "admin" .Values.proxysql.auth.proxysqlUser | b64enc | quote }}
{{- end -}}
{{- define "proxysql.auth.admin.password" -}}
{{ default "admin" .Values.proxysql.auth.proxysqlPassword | b64enc | quote }}
{{- end -}}

{{- define "proxysql.names.name" -}}
{{- default "proxysql" .Values.proxysql.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Kubernetes proxysql labels
*/}}
{{- define "proxysql.labels.standard" -}}
app.kubernetes.io/name: {{ include "proxysql.names.name" . }}
helm.sh/chart: {{ include "common.names.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Labels to use on proxysql deploy.spec.selector.matchLabels and svc.spec.selector
*/}}
{{- define "proxysql.labels.matchLabels" -}}
app.kubernetes.io/name: {{ include "proxysql.names.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}