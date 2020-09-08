{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "dgraph.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 24 -}}
{{- end -}}
{{/*
Create a default fully qualified app name.
We truncate at 24 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dgraph.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 24 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 24 -}}
{{- end -}}
{{- end -}}
{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dgraph.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified data name.
*/}}
{{- define "dgraph.zero.fullname" -}}
{{ template "dgraph.fullname" . }}-{{ .Values.zero.name }}
{{- end -}}

{{/*
Return the proper image name (for the metrics image)
*/}}
{{- define "dgraph.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | toString -}}
{{/*
Helm 2.11 supports the assignment of a value to a variable defined in a different scope,
but Helm 2.9 and 2.10 doesn't support it, so we need to implement this if-else logic.
Also, we can't use a single if because lazy evaluation is not an option
*/}}
{{- if .Values.global }}
    {{- if .Values.global.imageRegistry }}
        {{- printf "%s/%s:%s" .Values.global.imageRegistry $repositoryName $tag -}}
    {{- else -}}
        {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
    {{- end -}}
{{- else -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "dgraph.imagePullSecrets" -}}
{{/*
Helm 2.11 supports the assignment of a value to a variable defined in a different scope,
but Helm 2.9 and 2.10 doesn't support it, so we need to implement this if-else logic.
Also, we can't use a single if because lazy evaluation is not an option
*/}}
{{- if .Values.global }}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- else if .Values.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- else if .Values.image.pullSecrets }}
imagePullSecrets:
{{- range .Values.image.pullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified alpha name.
*/}}
{{- define "dgraph.alpha.fullname" -}}
{{ template "dgraph.fullname" . }}-{{ .Values.alpha.name }}
{{- end -}}


{{/*
Create a default fully qualified ratel name.
*/}}
{{- define "dgraph.ratel.fullname" -}}
{{ template "dgraph.fullname" . }}-{{ .Values.ratel.name }}
{{- end -}}

{{- /* Generate comma-separated list of Zeros */}}
{{- define "multi_zeros" -}}
  {{- $zeroFullName := include "dgraph.zero.fullname" . -}}
  {{- $max := int .Values.zero.replicaCount -}}
  {{- /* Create semverCompare() safe version if 'master' or 'latest' */ -}}
  {{- $safeVersion := .Values.image.tag -}}
  {{- if (eq $safeVersion "shuri") -}}
    {{- $safeVersion = "20.07.0" -}}
  {{- else if  (regexMatch "^[^v].*" $safeVersion) -}}
    {{- $safeVersion = "v50.0.0" -}}
  {{- end -}}
  {{- /* Reset $max to 1 if multiple zeros not supported by dgraph version */}}
  {{- if semverCompare "< 1.2.3 || 20.03.0" $safeVersion -}}
     {{- $max = 1 -}}
  {{- end -}}
  {{- /* Create comma-separated list of zeros */}}
  {{- range $idx := until $max }}
    {{- printf "%s-%d.%s-headless.${POD_NAMESPACE}.svc.cluster.local:5080" $zeroFullName $idx $zeroFullName -}}
    {{- if ne $idx (sub $max 1) -}}
      {{- print "," -}}
    {{- end -}}
  {{ end }}
{{- end -}}
