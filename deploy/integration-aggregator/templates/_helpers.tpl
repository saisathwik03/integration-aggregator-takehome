{{- define "integration-aggregator.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "integration-aggregator.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name -}}
{{- end -}}

{{- define "integration-aggregator.serviceAccountName" -}}
{{- printf "%s-sa" (include "integration-aggregator.fullname" .) -}}
{{- end -}}