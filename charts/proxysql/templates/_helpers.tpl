{{/*
Expand the name of the chart.
*/}}
{{- define "proxysql.name" -}}
{{- printf "%s-%s" .Release.Name "proxysql" | trunc 63 | trimSuffix "-" }}
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