$LLM_SERVICE_URL = (gcloud run services describe $env:LLM_SERVICE --region $env:REGION --format="value(status.url)").Trim()
$ID_TOKEN = (gcloud auth print-identity-token).Trim()

$headers = @{
    "Authorization" = "Bearer $ID_TOKEN"
    "Content-Type" = "application/json"
}

$body = @{
    "model" = "SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0"
    "messages" = @(
        @{ "role" = "user"; "content" = "Jak często powinien być mierzony poziom chloru w basenie?" }
    )
    "stream" = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "$LLM_SERVICE_URL/api/chat" -Method Post -Headers $headers -Body $body
