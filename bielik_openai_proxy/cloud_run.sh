#!/bin/bash
set -euo pipefail

if [ -z "${PROJECT_ID:-}" ] || [ -z "${REGION:-}" ] || [ -z "${LLM_SERVICE:-}" ]; then
  echo "Missing PROJECT_ID, REGION, or LLM_SERVICE. Run: source ../setup_env.sh"
  exit 1
fi

if [ -z "${PROXY_SERVICE:-}" ]; then
  export PROXY_SERVICE="bielik-openai-proxy"
fi

if [ -z "${PROXY_SERVICE_ACCOUNT:-}" ]; then
  echo "Missing PROXY_SERVICE_ACCOUNT env var"
  exit 1
fi

if [ -z "${TRIAL_API_KEY:-}" ]; then
  echo "Missing TRIAL_API_KEY env var"
  exit 1
fi

if [ -z "${UPSTREAM_MODEL_NAME:-}" ]; then
  export UPSTREAM_MODEL_NAME="SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0"
fi

export UPSTREAM_LLM_URL=$(gcloud run services describe "$LLM_SERVICE" --region "$REGION" --format 'value(status.url)')

if [ -z "$UPSTREAM_LLM_URL" ]; then
  echo "Could not resolve upstream Cloud Run URL for $LLM_SERVICE"
  exit 1
fi

if [ -z "${UPSTREAM_AUDIENCE:-}" ]; then
  export UPSTREAM_AUDIENCE="$UPSTREAM_LLM_URL"
fi

if [ -z "${REQUEST_TIMEOUT:-}" ]; then
  export REQUEST_TIMEOUT="600"
fi

gcloud run deploy "$PROXY_SERVICE" \
  --source . \
  --region "$REGION" \
  --allow-unauthenticated \
  --service-account "$PROXY_SERVICE_ACCOUNT" \
  --set-env-vars TRIAL_API_KEY="$TRIAL_API_KEY",UPSTREAM_LLM_URL="$UPSTREAM_LLM_URL",UPSTREAM_MODEL_NAME="$UPSTREAM_MODEL_NAME",UPSTREAM_AUDIENCE="$UPSTREAM_AUDIENCE",REQUEST_TIMEOUT="$REQUEST_TIMEOUT"
