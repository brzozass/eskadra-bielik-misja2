$env:PROJECT_ID = (gcloud config get-value project)
$env:REGION = "europe-west1"
$env:EMBEDDING_SERVICE = "embedding-gemma"
$env:LLM_SERVICE = "bielik"
$env:BIGQUERY_DATASET = "rag_dataset"
$env:BIGQUERY_TABLE = "hotel_rules"

Write-Host "Wczytano zmienne środowiskowe:"
Write-Host "  PROJECT_ID: $env:PROJECT_ID"
Write-Host "  REGION: $env:REGION"
Write-Host "  EMBEDDING_SERVICE: $env:EMBEDDING_SERVICE"
Write-Host "  LLM_SERVICE: $env:LLM_SERVICE"
Write-Host "  BIGQUERY_DATASET: $env:BIGQUERY_DATASET"
Write-Host "  BIGQUERY_TABLE: $env:BIGQUERY_TABLE"
