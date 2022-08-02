{{/*
Expand the name of the release.
*/}}
{{- define "proxysql.name" -}}
{{- printf "%s-%s" .Release.Name "proxysql" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the release.
*/}}
{{- define "mysql.name" -}}
{{- printf "%s-%s" .Release.Name (include "mysql.serviceName" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the service domain of the chart.
*/}}
{{- define "mysql.serviceName" -}}
{{ default "mysql" .Values.global.mysql.service.name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "proxysql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return the proper ProxySQL image name
*/}}
{{- define "proxysql.image" -}}
{{- .Values.image.registry }}/{{- .Values.image.repository }}:{{- .Values.image.tag }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "proxysql.imagePullSecrets" -}}
  {{- if not (empty .Values.image.pullSecrets) }}
imagePullSecrets:
    {{- range .Values.image.pullSecrets -}}
- name: {{ . }}
    {{- end }}
  {{- end }}
{{- end -}}