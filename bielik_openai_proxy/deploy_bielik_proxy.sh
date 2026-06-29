#!/bin/bash
set -euo pipefail

# ============================================================
# Bielik OpenAI Proxy - kompletny deploy do Cloud Run
# Uruchom w Google Cloud Shell
# ============================================================

echo "=== 1/12 Klonowanie repo ==="
cd ~
if [ -d eskadra-bielik-misja2 ]; then
  cd eskadra-bielik-misja2
  git pull || true
  echo "Aktualizacja repozytorium..."
  if ! git pull; then
    echo "UWAGA: 'git pull' nie powiódł się. Kontynuuję z aktualną wersją lokalną."
  fi
else
  git clone https://github.com/kasperkalfas/eskadra-bielik-misja2.git
  cd eskadra-bielik-misja2
fi

echo "=== 2/12 Tworzenie plikow proxy ==="
# Nie nadpisujemy plikow, jesli juz istnieja w katalogu.
# Pozwala to zachowac wersje app.py z obsługa NDJSON.
mkdir -p bielik_openai_proxy

echo "=== 3/12 Ustawianie srodowiska ==="
source setup_env.sh
echo "PROJECT_ID=$PROJECT_ID"
echo "REGION=$REGION"
echo "LLM_SERVICE=$LLM_SERVICE"

echo "=== 4/12 Sprawdzanie serwisu bielik ==="
if ! gcloud run services describe "$LLM_SERVICE" --region "$REGION" >/dev/null 2>&1; then
  echo "BLAD: Serwis $LLM_SERVICE nie istnieje w regionie $REGION."
  echo "Najpierw wdroz bielik LLM: cd llm && ./cloud_run.sh"
  exit 1
fi
echo "Serwis bielik istnieje."

echo "=== 5/12 Tworzenie service account ==="
PROXY_SERVICE="bielik-openai-proxy"
PROXY_SA_NAME="bielik-proxy-sa"
PROXY_SERVICE_ACCOUNT="${PROXY_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$PROXY_SERVICE_ACCOUNT" >/dev/null 2>&1; then
  echo "Service account juz istnieje."
else
  gcloud iam service-accounts create "$PROXY_SA_NAME" \
    --display-name="Bielik OpenAI Proxy SA"
  echo "Utworzono service account."
fi

echo "=== 6/12 Nadawanie roles/run.invoker na serwis bielik ==="
gcloud run services add-iam-policy-binding "$LLM_SERVICE" \
  --region "$REGION" \
  --member "serviceAccount:${PROXY_SERVICE_ACCOUNT}" \
  --role "roles/run.invoker" \
  --quiet
echo "Nadano uprawnienia."

echo "=== 7/12 Generowanie API key ==="
TRIAL_API_KEY=$(openssl rand -hex 32)
echo ""
echo "Twoj TRIAL_API_KEY (ZAPISZ GO - potrzebny do Hermesa):"
echo "  $TRIAL_API_KEY"
echo ""

echo "=== 8/12 Pobieranie URL upstreama ==="
UPSTREAM_LLM_URL=$(gcloud run services describe "$LLM_SERVICE" --region "$REGION" --format='value(status.url)')
UPSTREAM_AUDIENCE="$UPSTREAM_LLM_URL"
UPSTREAM_MODEL_NAME="SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0"
UPSTREAM_MODEL_NAME="${UPSTREAM_MODEL_NAME:-SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0}"
echo "UPSTREAM_LLM_URL=$UPSTREAM_LLM_URL"

echo "=== 9/12 Deploy proxy do Cloud Run ==="
cd bielik_openai_proxy

gcloud run deploy "$PROXY_SERVICE" \
  --source . \
  --region "$REGION" \
  --allow-unauthenticated \
  --service-account "$PROXY_SERVICE_ACCOUNT" \
  --set-env-vars TRIAL_API_KEY="${TRIAL_API_KEY}" \
  --set-env-vars UPSTREAM_LLM_URL="${UPSTREAM_LLM_URL}" \
  --set-env-vars UPSTREAM_MODEL_NAME="${UPSTREAM_MODEL_NAME}" \
  --set-env-vars UPSTREAM_AUDIENCE="${UPSTREAM_AUDIENCE}" \
  --timeout "600"

cd ..

echo "=== 10/12 Pobieranie URL proxy ==="
PROXY_URL=$(gcloud run services describe "$PROXY_SERVICE" --region "$REGION" --format='value(status.url)')
echo "PROXY_URL=$PROXY_URL"
echo ""

echo "=== 11/12 Testy curl ==="
echo "--- Health check ---"
curl -s "$PROXY_URL/healthz"
echo ""

echo "--- /v1/models (bez auth, oczekiwane 401) ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$PROXY_URL/v1/models"

echo "--- /v1/models (z auth) ---"
curl -s "$PROXY_URL/v1/models" \
  -H "Authorization: Bearer $TRIAL_API_KEY"
echo ""

echo "--- /v1/chat/completions ---"
curl -s "$PROXY_URL/v1/chat/completions" \
  -H "Authorization: Bearer $TRIAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0",
    "messages": [{"role": "user", "content": "Napisz dwa zdania po polsku o Krakowie."}],
    "stream": false
  }'
echo ""

echo ""
echo "============================================================"
echo "=== 12/12 KONFIGURACJA HERMES (zapisz na swoim komputerze) ==="
echo "============================================================"
echo ""
echo "Plik: C:\\Users\\darek\\AppData\\Local\\hermes\\.env"
echo "Dodaj linijke:"
echo "  BIELIK_HERMES_API_KEY=$TRIAL_API_KEY"
echo ""
echo "Plik: C:\\Users\\darek\\AppData\\Local\\hermes\\config.yaml"
echo "Dodaj sekcje:"
echo "  custom_providers:"
echo "    - name: bielik-gcp"
echo "      base_url: ${PROXY_URL}/v1"
echo "      key_env: BIELIK_HERMES_API_KEY"
echo "      api_mode: chat_completions"
echo ""
echo "  model:"
echo "    provider: custom:bielik-gcp"
echo "    default: SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0"
echo "    context_length: 64000"
echo ""
echo "============================================================"
echo "Gdy skonczysz, uruchom lokalnie:"
echo "  hermes doctor"
echo "  hermes"
echo "i w nowej sesji napisz: Napisz 2 zdania po polsku o Krakowie."
echo "============================================================"
