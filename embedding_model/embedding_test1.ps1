$EMBEDDING_SERVICE_URL = (gcloud run services describe $env:EMBEDDING_SERVICE --region $env:REGION --format="value(status.url)").Trim()
$ID_TOKEN = (gcloud auth print-identity-token).Trim()

$headers = @{
    "Authorization" = "Bearer $ID_TOKEN"
    "Content-Type" = "application/json"
}

$body = @{
    "model" = "embeddinggemma"
    "input" = "Przykładowy tekst testowy"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$EMBEDDING_SERVICE_URL/api/embed" -Method Post -Headers $headers -Body $body
