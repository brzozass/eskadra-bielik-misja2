# Bielik OpenAI Proxy

This directory contains a standalone Cloud Run service that exposes a private Ollama/Bielik backend through an OpenAI-compatible API for Hermes.

## What it does

- `GET /healthz`
- `GET /v1/models`
- `POST /v1/chat/completions`
- validates an external bearer API key (`TRIAL_API_KEY`)
- fetches a Google identity token for the private upstream Cloud Run service
- forwards requests to the upstream Ollama endpoint: `/api/chat`

## Required environment variables

- `PROJECT_ID`
- `REGION`
- `LLM_SERVICE`
- `PROXY_SERVICE_ACCOUNT`
- `TRIAL_API_KEY`
- `UPSTREAM_MODEL_NAME` (optional, default is Bielik from the repo)
- `REQUEST_TIMEOUT` (optional, default `600`)

Load project defaults first:

```bash
source ../setup_env.sh
```

Then set the proxy-specific variables:

```bash
export PROXY_SERVICE=bielik-openai-proxy
export PROXY_SERVICE_ACCOUNT=bielik-proxy-sa@${PROJECT_ID}.iam.gserviceaccount.com
export TRIAL_API_KEY='replace-with-a-long-random-secret'
export UPSTREAM_MODEL_NAME='SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0'
```

## Deploy

```bash
cd bielik_openai_proxy
chmod +x cloud_run.sh
./cloud_run.sh
```

## IAM prerequisite

The service account used by the proxy must have `roles/run.invoker` on the private `bielik` service.

Example:

```bash
gcloud run services add-iam-policy-binding "$LLM_SERVICE" \
  --region "$REGION" \
  --member "serviceAccount:${PROXY_SERVICE_ACCOUNT}" \
  --role "roles/run.invoker"
```

## Smoke test

After deploy, get the URL:

```bash
export PROXY_URL=$(gcloud run services describe "$PROXY_SERVICE" --region "$REGION" --format='value(status.url)')
```

List models:

```bash
curl "$PROXY_URL/v1/models" \
  -H "Authorization: Bearer $TRIAL_API_KEY"
```

Chat completion:

```bash
curl "$PROXY_URL/v1/chat/completions" \
  -H "Authorization: Bearer $TRIAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0",
    "messages": [{"role": "user", "content": "Napisz dwa zdania po polsku o Krakowie."}],
    "stream": false
  }'
```

## Hermes config example

`~/.hermes/.env`

```env
BIELIK_HERMES_API_KEY=replace-with-the-same-secret
```

`~/.hermes/config.yaml`

```yaml
custom_providers:
  - name: bielik-gcp
    base_url: https://YOUR_PROXY_URL.run.app/v1
    key_env: BIELIK_HERMES_API_KEY
    api_mode: chat_completions

model:
  provider: custom:bielik-gcp
  default: SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0
  context_length: 64000
```
