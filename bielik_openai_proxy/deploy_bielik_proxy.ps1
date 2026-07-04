Write-Host "=== 1/11 Inicjalizacja środowiska ==="
. .\setup_env.ps1

$PROXY_SERVICE = "bielik-openai-proxy"
$PROXY_SA_NAME = "bielik-proxy-sa"
$PROXY_SERVICE_ACCOUNT = "${PROXY_SA_NAME}@$($env:PROJECT_ID).iam.gserviceaccount.com"

# Sprawdzenie czy usługa LLM działa
if (-not (gcloud run services describe $env:LLM_SERVICE --region $env:REGION 2>$null)) {
    Write-Error "BŁĄD: Serwis $($env:LLM_SERVICE) nie istnieje w regionie $($env:REGION). Najpierw wdróż Bielik LLM."
    exit 1
}

Write-Host "=== 2/11 Tworzenie Service Account ==="
$saExists = gcloud iam service-accounts describe $PROXY_SERVICE_ACCOUNT 2>$null
if ($saExists) {
    Write-Host "Service account już istnieje."
} else {
    gcloud iam service-accounts create $PROXY_SA_NAME --display-name="Bielik OpenAI Proxy SA"
    Write-Host "Utworzono service account."
}

Write-Host "=== 3/11 Nadawanie uprawnień Invokera ==="
gcloud run services add-iam-policy-binding $env:LLM_SERVICE `
  --region $env:REGION `
  --member "serviceAccount:$PROXY_SERVICE_ACCOUNT" `
  --role "roles/run.invoker" `
  --quiet

Write-Host "=== 4/11 Generowanie klucza API ==="
$bytes = New-Object Byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:TRIAL_API_KEY = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
Write-Host ""
Write-Host "Twój TRIAL_API_KEY (Zapisz go dla Hermesa):"
Write-Host "  $($env:TRIAL_API_KEY)"
Write-Host ""

Write-Host "=== 5/11 Pobieranie URL upstream ==="
$UPSTREAM_LLM_URL = (gcloud run services describe $env:LLM_SERVICE --region $env:REGION --format='value(status.url)').Trim()
Write-Host "UPSTREAM_LLM_URL=$UPSTREAM_LLM_URL"

Write-Host "=== 6/11 Deploy proxy do Cloud Run ==="
Push-Location .\bielik_openai_proxy
. .\cloud_run.ps1
Pop-Location

Write-Host "=== 7/11 Pobieranie URL proxy ==="
$PROXY_URL = (gcloud run services describe $PROXY_SERVICE --region $env:REGION --format='value(status.url)').Trim()
Write-Host "PROXY_URL=$PROXY_URL"

Write-Host "=== 8/11 Testy dymne ==="
Write-Host "--- Health check ---"
Invoke-RestMethod -Uri "$PROXY_URL/healthz" -Method Get

Write-Host "--- /v1/models (z auth) ---"
$headers = @{
    "Authorization" = "Bearer $($env:TRIAL_API_KEY)"
}
Invoke-RestMethod -Uri "$PROXY_URL/v1/models" -Method Get -Headers $headers

Write-Host "--- /v1/chat/completions ---"
$body = @{
    "model" = "SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0"
    "messages" = @(
        @{ "role" = "user"; "content" = "Napisz dwa zdania po polsku o Krakowie." }
    )
    "stream" = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "$PROXY_URL/v1/chat/completions" -Method Post -Headers $headers -Body $body -ContentType "application/json"
