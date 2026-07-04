if (-not $env:PROXY_SERVICE) {
    $env:PROXY_SERVICE = "bielik-openai-proxy"
}
if (-not $env:PROXY_SERVICE_ACCOUNT) {
    $env:PROXY_SERVICE_ACCOUNT = "bielik-proxy-sa@$($env:PROJECT_ID).iam.gserviceaccount.com"
}
if (-not $env:UPSTREAM_MODEL_NAME) {
    $env:UPSTREAM_MODEL_NAME = "SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0"
}
if (-not $env:REQUEST_TIMEOUT) {
    $env:REQUEST_TIMEOUT = "600"
}

$UPSTREAM_LLM_URL = (gcloud run services describe $env:LLM_SERVICE --region $env:REGION --format 'value(status.url)')
if (-not $UPSTREAM_LLM_URL) {
    Write-Error "Nie można pobrać adresu URL usługi $env:LLM_SERVICE"
    exit 1
}

$env:UPSTREAM_AUDIENCE = $UPSTREAM_LLM_URL

gcloud run deploy $env:PROXY_SERVICE `
  --source . `
  --region $env:REGION `
  --allow-unauthenticated `
  --service-account $env:PROXY_SERVICE_ACCOUNT `
  --set-env-vars "TRIAL_API_KEY=$($env:TRIAL_API_KEY),UPSTREAM_LLM_URL=$($UPSTREAM_LLM_URL),UPSTREAM_MODEL_NAME=$($env:UPSTREAM_MODEL_NAME),UPSTREAM_AUDIENCE=$($env:UPSTREAM_AUDIENCE),REQUEST_TIMEOUT=$($env:REQUEST_TIMEOUT)"
