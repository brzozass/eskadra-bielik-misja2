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
else
  git clone https://github.com/kasperkalfas/eskadra-bielik-misja2.git
  cd eskadra-bielik-misja2
fi

echo "=== 2/12 Tworzenie plikow proxy ==="
mkdir -p bielik_openai_proxy

# Write app.py from base64
echo "aW1wb3J0IG9zCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCmZyb20gdHlwaW5nIGltcG9ydCBBbnkKCmltcG9ydCByZXF1ZXN0cwpmcm9tIGZhc3RhcGkgaW1wb3J0IEZhc3RBUEksIEhlYWRlciwgSFRUUEV4Y2VwdGlvbgpmcm9tIGdvb2dsZS5hdXRoLnRyYW5zcG9ydC5yZXF1ZXN0cyBpbXBvcnQgUmVxdWVzdApmcm9tIGdvb2dsZS5vYXV0aDIuaWRfdG9rZW4gaW1wb3J0IGZldGNoX2lkX3Rva2VuCmZyb20gcHlkYW50aWMgaW1wb3J0IEJhc2VNb2RlbCwgRmllbGQKCgpjbGFzcyBDaGF0Q29tcGxldGlvbnNSZXF1ZXN0KEJhc2VNb2RlbCk6CiAgICBtb2RlbDogc3RyCiAgICBtZXNzYWdlczogbGlzdFtkaWN0W3N0ciwgQW55XV0gPSBGaWVsZChkZWZhdWx0X2ZhY3Rvcnk9bGlzdCkKICAgIHN0cmVhbTogYm9vbCA9IEZhbHNlCgoKY2xhc3MgUHJveHlDb25maWcoQmFzZU1vZGVsKToKICAgIHRyaWFsX2FwaV9rZXk6IHN0cgogICAgdXBzdHJlYW1fbGxtX3VybDogc3RyCiAgICB1cHN0cmVhbV9tb2RlbF9uYW1lOiBzdHIKICAgIHVwc3RyZWFtX2F1ZGllbmNlOiBzdHIgfCBOb25lID0gTm9uZQogICAgcmVxdWVzdF90aW1lb3V0OiBpbnQgPSA2MDAKCgpERUZBVUxUX1NFVFRJTkdTID0gewogICAgIlRSSUFMX0FQSV9LRVkiOiBvcy5nZXRlbnYoIlRSSUFMX0FQSV9LRVkiLCAiIiksCiAgICAiVVBTVFJFQU1fTExNX1VSTCI6IG9zLmdldGVudigiVVBTVFJFQU1fTExNX1VSTCIsICIiKSwKICAgICJVUFNUUkVBTV9NT0RFTF9OQU1FIjogb3MuZ2V0ZW52KCJVUFNUUkVBTV9NT0RFTF9OQU1FIiwgIiIpLAogICAgIlVQU1RSRUFNX0FVRElFTkNFIjogb3MuZ2V0ZW52KCJVUFNUUkVBTV9BVURJRU5DRSIsICIiKSwKICAgICJSRVFVRVNUX1RJTUVPVVQiOiBvcy5nZXRlbnYoIlJFUVVFU1RfVElNRU9VVCIsICI2MDAiKSwKfQoKCmRlZiByZXF1aXJlX2FwaV9rZXkoYXV0aG9yaXphdGlvbl9oZWFkZXIsIGV4cGVjdGVkX2FwaV9rZXkpOgogICAgcHJlZml4ID0gIkJlYXJlciAiCiAgICBpZiBub3QgYXV0aG9yaXphdGlvbl9oZWFkZXIgb3Igbm90IGF1dGhvcml6YXRpb25faGVhZGVyLnN0YXJ0c3dpdGgocHJlZml4KToKICAgICAgICByYWlzZSBQZXJtaXNzaW9uRXJyb3IoIk1pc3NpbmcgYmVhcmVyIHRva2VuIikKICAgIHRva2VuID0gYXV0aG9yaXphdGlvbl9oZWFkZXJbbGVuKHByZWZpeCk6XQogICAgaWYgdG9rZW4gIT0gZXhwZWN0ZWRfYXBpX2tleToKICAgICAgICByYWlzZSBQZXJtaXNzaW9uRXJyb3IoIkludmFsaWQgQVBJIGtleSIpCiAgICByZXR1cm4gdG9rZW4KCgpkZWYgYnVpbGRfb2xsYW1hX3BheWxvYWQocGF5bG9hZCk6CiAgICByZXR1cm4gewogICAgICAgICJtb2RlbCI6IHBheWxvYWRbIm1vZGVsIl0sCiAgICAgICAgIm1lc3NhZ2VzIjogcGF5bG9hZC5nZXQoIm1lc3NhZ2VzIiwgW10pLAogICAgICAgICJzdHJlYW0iOiBib29sKHBheWxvYWQuZ2V0KCJzdHJlYW0iLCBGYWxzZSkpLAogICAgfQoKCmRlZiBidWlsZF9vcGVuYWlfcmVzcG9uc2Uob2xsYW1hX3Jlc3BvbnNlLCBtb2RlbCk6CiAgICBtZXNzYWdlID0gb2xsYW1hX3Jlc3BvbnNlLmdldCgibWVzc2FnZSIsIHt9KQogICAgcmV0dXJuIHsKICAgICAgICAiaWQiOiAiY2hhdGNtcGwtIiArIHV1aWQudXVpZDQoKS5oZXgsCiAgICAgICAgIm9iamVjdCI6ICJjaGF0LmNvbXBsZXRpb24iLAogICAgICAgICJjcmVhdGVkIjogaW50KHRpbWUudGltZSgpKSwKICAgICAgICAibW9kZWwiOiBtb2RlbCwKICAgICAgICAiY2hvaWNlcyI6IFsKICAgICAgICAgICAgewogICAgICAgICAgICAgICAgImluZGV4IjogMCwKICAgICAgICAgICAgICAgICJtZXNzYWdlIjogewogICAgICAgICAgICAgICAgICAgICJyb2xlIjogbWVzc2FnZS5nZXQoInJvbGUiLCAiYXNzaXN0YW50IiksCiAgICAgICAgICAgICAgICAgICAgImNvbnRlbnQiOiBtZXNzYWdlLmdldCgiY29udGVudCIsICIiKSwKICAgICAgICAgICAgICAgIH0sCiAgICAgICAgICAgICAgICAiZmluaXNoX3JlYXNvbiI6IG9sbGFtYV9yZXNwb25zZS5nZXQoImRvbmVfcmVhc29uIiwgInN0b3AiKSwKICAgICAgICAgICAgfQogICAgICAgIF0sCiAgICB9CgoKZGVmIGZldGNoX2dvb2dsZV9iZWFyZXJfdG9rZW4oYXVkaWVuY2UpOgogICAgcmV0dXJuIGZldGNoX2lkX3Rva2VuKFJlcXVlc3QoKSwgYXVkaWVuY2UpCgoKZGVmIGNhbGxfdXBzdHJlYW1fb2xsYW1hKGNvbmZpZywgcGF5bG9hZCk6CiAgICBhdWRpZW5jZSA9IGNvbmZpZy51cHN0cmVhbV9hdWRpZW5jZSBvciBjb25maWcudXBzdHJlYW1fbGxtX3VybAogICAgdG9rZW4gPSBmZXRjaF9nb29nbGVfYmVhcmVyX3Rva2VuKGF1ZGllbmNlKQogICAgcmVzcG9uc2UgPSByZXF1ZXN0cy5wb3N0KAogICAgICAgIGNvbmZpZy51cHN0cmVhbV9sbG1fdXJsLnJzdHJpcCgiLyIpICsgIi9hcGkvY2hhdCIsCiAgICAgICAganNvbj1wYXlsb2FkLAogICAgICAgIGhlYWRlcnM9ewogICAgICAgICAgICAiQXV0aG9yaXphdGlvbiI6ICJCZWFyZXIgIiArIHRva2VuLAogICAgICAgICAgICAiQ29udGVudC1UeXBlIjogImFwcGxpY2F0aW9uL2pzb24iLAogICAgICAgIH0sCiAgICAgICAgdGltZW91dD1jb25maWcucmVxdWVzdF90aW1lb3V0LAogICAgKQogICAgcmVzcG9uc2UucmFpc2VfZm9yX3N0YXR1cygpCiAgICByZXR1cm4gcmVzcG9uc2UuanNvbigpCgoKZGVmIGxvYWRfY29uZmlnKHNldHRpbmdzPU5vbmUpOgogICAgcmF3ID0gZGljdChERUZBVUxUX1NFVFRJTkdTKQogICAgaWYgc2V0dGluZ3M6CiAgICAgICAgcmF3LnVwZGF0ZShzZXR0aW5ncykKICAgIHJldHVybiBQcm94eUNvbmZpZygKICAgICAgICB0cmlhbF9hcGlfa2V5PXJhd1siVFJJQUxfQVBJX0tFWSJdLAogICAgICAgIHVwc3RyZWFtX2xsbV91cmw9cmF3WyJVUFNUUkVBTV9MTE1fVVJMIl0sCiAgICAgICAgdXBzdHJlYW1fbW9kZWxfbmFtZT1yYXdbIlVQU1RSRUFNX01PREVMX05BTUUiXSwKICAgICAgICB1cHN0cmVhbV9hdWRpZW5jZT1yYXcuZ2V0KCJVUFNUUkVBTV9BVURJRU5DRSIpIG9yIE5vbmUsCiAgICAgICAgcmVxdWVzdF90aW1lb3V0PWludChyYXcuZ2V0KCJSRVFVRVNUX1RJTUVPVVQiLCA2MDApKSwKICAgICkKCgpkZWYgY3JlYXRlX2FwcChzZXR0aW5ncz1Ob25lKToKICAgIGNvbmZpZyA9IGxvYWRfY29uZmlnKHNldHRpbmdzKQogICAgYXBwID0gRmFzdEFQSSh0aXRsZT0iQmllbGlrIE9wZW5BSSBQcm94eSIpCgogICAgQGFwcC5nZXQoIi9oZWFsdGh6IikKICAgIGRlZiBoZWFsdGh6KCk6CiAgICAgICAgcmV0dXJuIHsic3RhdHVzIjogIm9rIn0KCiAgICBAYXBwLmdldCgiL3YxL21vZGVscyIpCiAgICBkZWYgbGlzdF9tb2RlbHMoYXV0aG9yaXphdGlvbj1IZWFkZXIoZGVmYXVsdD1Ob25lKSk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICByZXF1aXJlX2FwaV9rZXkoYXV0aG9yaXphdGlvbiwgY29uZmlnLnRyaWFsX2FwaV9rZXkpCiAgICAgICAgZXhjZXB0IFBlcm1pc3Npb25FcnJvciBhcyBleGM6CiAgICAgICAgICAgIHJhaXNlIEhUVFBFeGNlcHRpb24oc3RhdHVzX2NvZGU9NDAxLCBkZXRhaWw9c3RyKGV4YykpIGZyb20gZXhjCiAgICAgICAgcmV0dXJuIHsKICAgICAgICAgICAgIm9iamVjdCI6ICJsaXN0IiwKICAgICAgICAgICAgImRhdGEiOiBbCiAgICAgICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAgImlkIjogY29uZmlnLnVwc3RyZWFtX21vZGVsX25hbWUsCiAgICAgICAgICAgICAgICAgICAgIm9iamVjdCI6ICJtb2RlbCIsCiAgICAgICAgICAgICAgICAgICAgIm93bmVkX2J5IjogImVza2FkcmEtYmllbGlrIiwKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgXSwKICAgICAgICB9CgogICAgQGFwcC5wb3N0KCIvdjEvY2hhdC9jb21wbGV0aW9ucyIpCiAgICBkZWYgY2hhdF9jb21wbGV0aW9ucyhib2R5OiBDaGF0Q29tcGxldGlvbnNSZXF1ZXN0LCBhdXRob3JpemF0aW9uPUhlYWRlcihkZWZhdWx0PU5vbmUpKToKICAgICAgICB0cnk6CiAgICAgICAgICAgIHJlcXVpcmVfYXBpX2tleShhdXRob3JpemF0aW9uLCBjb25maWcudHJpYWxfYXBpX2tleSkKICAgICAgICBleGNlcHQgUGVybWlzc2lvbkVycm9yIGFzIGV4YzoKICAgICAgICAgICAgcmFpc2UgSFRUUEV4Y2VwdGlvbihzdGF0dXNfY29kZT00MDEsIGRldGFpbD1zdHIoZXhjKSkgZnJvbSBleGMKICAgICAgICBwYXlsb2FkID0gYnVpbGRfb2xsYW1hX3BheWxvYWQoYm9keS5tb2RlbF9kdW1wKCkpCiAgICAgICAgdHJ5OgogICAgICAgICAgICB1cHN0cmVhbV9yZXNwb25zZSA9IGNhbGxfdXBzdHJlYW1fb2xsYW1hKGNvbmZpZywgcGF5bG9hZCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uIGFzIGV4YzoKICAgICAgICAgICAgcmFpc2UgSFRUUEV4Y2VwdGlvbihzdGF0dXNfY29kZT01MDIsIGRldGFpbD0iVXBzdHJlYW0gQmllbGlrIGVycm9yOiAiICsgc3RyKGV4YykpIGZyb20gZXhjCiAgICAgICAgcmV0dXJuIGJ1aWxkX29wZW5haV9yZXNwb25zZSh1cHN0cmVhbV9yZXNwb25zZSwgYm9keS5tb2RlbCkKCiAgICByZXR1cm4gYXBwCgoKYXBwID0gY3JlYXRlX2FwcCgpCg==" | base64 -d > bielik_openai_proxy/app.py
echo "RlJPTSBweXRob246My4xMS1zbGltCldPUktESVIgL2FwcApDT1BZIHJlcXVpcmVtZW50cy50eHQgLgpSVU4gcGlwIGluc3RhbGwgLS1uby1jYWNoZS1kaXIgLXIgcmVxdWlyZW1lbnRzLnR4dApDT1BZIC4gLgpDTUQgWyJ1dmljb3JuIiwgImFwcDphcHAiLCAiLS1ob3N0IiwgIjAuMC4wLjAiLCAiLS1wb3J0IiwgIjgwODAiXQo=" | base64 -d > bielik_openai_proxy/Dockerfile
echo "ZmFzdGFwaT09MC4xMTEuMAp1dmljb3JuPT0wLjI5LjAKcmVxdWVzdHM9PTIuMzEuMApnb29nbGUtYXV0aD09Mi4yOS4wCg==" | base64 -d > bielik_openai_proxy/requirements.txt
touch bielik_openai_proxy/__init__.py

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
echo "UPSTREAM_LLM_URL=$UPSTREAM_LLM_URL"

echo "=== 9/12 Deploy proxy do Cloud Run ==="
cd bielik_openai_proxy

gcloud run deploy "$PROXY_SERVICE" \
  --source . \
  --region "$REGION" \
  --allow-unauthenticated \
  --service-account "$PROXY_SERVICE_ACCOUNT" \
  --set-env-vars \
    TRIAL_API_KEY="$TRIAL_API_KEY" \
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
