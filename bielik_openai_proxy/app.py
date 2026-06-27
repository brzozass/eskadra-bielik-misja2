import os
import time
import uuid
from typing import Any

import requests
from fastapi import FastAPI, Header, HTTPException
from google.auth.transport.requests import Request
from google.oauth2.id_token import fetch_id_token
from pydantic import BaseModel, Field


class ChatCompletionsRequest(BaseModel):
    model: str
    messages: list[dict[str, Any]] = Field(default_factory=list)
    stream: bool = False


class ProxyConfig(BaseModel):
    trial_api_key: str
    upstream_llm_url: str
    upstream_model_name: str
    upstream_audience: str | None = None
    request_timeout: int = 600


DEFAULT_SETTINGS = {
    "TRIAL_API_KEY": os.getenv("TRIAL_API_KEY", ""),
    "UPSTREAM_LLM_URL": os.getenv("UPSTREAM_LLM_URL", ""),
    "UPSTREAM_MODEL_NAME": os.getenv("UPSTREAM_MODEL_NAME", ""),
    "UPSTREAM_AUDIENCE": os.getenv("UPSTREAM_AUDIENCE", ""),
    "REQUEST_TIMEOUT": os.getenv("REQUEST_TIMEOUT", "600"),
}


def require_api_key(authorization_header: str | None, expected_api_key: str) -> str:
    prefix = "Bearer "
    if not authorization_header or not authorization_header.startswith(prefix):
        raise PermissionError("Missing bearer token")

    token = authorization_header[len(prefix):]
    if token != expected_api_key:
        raise PermissionError("Invalid API key")

    return token


def build_ollama_payload(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "model": payload["model"],
        "messages": payload.get("messages", []),
        "stream": bool(payload.get("stream", False)),
    }


def build_openai_response(ollama_response: dict[str, Any], model: str) -> dict[str, Any]:
    message = ollama_response.get("message", {})
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": message.get("role", "assistant"),
                    "content": message.get("content", ""),
                },
                "finish_reason": ollama_response.get("done_reason", "stop"),
            }
        ],
    }


def fetch_google_bearer_token(audience: str) -> str:
    return fetch_id_token(Request(), audience)


def call_upstream_ollama(config: ProxyConfig, payload: dict[str, Any]) -> dict[str, Any]:
    audience = config.upstream_audience or config.upstream_llm_url
    token = fetch_google_bearer_token(audience)
    response = requests.post(
        f"{config.upstream_llm_url.rstrip('/')}/api/chat",
        json=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        timeout=config.request_timeout,
    )
    response.raise_for_status()
    return response.json()


def load_config(settings: dict[str, Any] | None = None) -> ProxyConfig:
    raw = dict(DEFAULT_SETTINGS)
    if settings:
        raw.update(settings)

    return ProxyConfig(
        trial_api_key=raw["TRIAL_API_KEY"],
        upstream_llm_url=raw["UPSTREAM_LLM_URL"],
        upstream_model_name=raw["UPSTREAM_MODEL_NAME"],
        upstream_audience=raw.get("UPSTREAM_AUDIENCE") or None,
        request_timeout=int(raw.get("REQUEST_TIMEOUT", 600)),
    )


def create_app(settings: dict[str, Any] | None = None) -> FastAPI:
    config = load_config(settings)
    app = FastAPI(title="Bielik OpenAI Proxy")

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/v1/models")
    def list_models(authorization: str | None = Header(default=None)) -> dict[str, Any]:
        try:
            require_api_key(authorization, config.trial_api_key)
        except PermissionError as exc:
            raise HTTPException(status_code=401, detail=str(exc)) from exc

        return {
            "object": "list",
            "data": [
                {
                    "id": config.upstream_model_name,
                    "object": "model",
                    "owned_by": "eskadra-bielik",
                }
            ],
        }

    @app.post("/v1/chat/completions")
    def chat_completions(
        body: ChatCompletionsRequest,
        authorization: str | None = Header(default=None),
    ) -> dict[str, Any]:
        try:
            require_api_key(authorization, config.trial_api_key)
        except PermissionError as exc:
            raise HTTPException(status_code=401, detail=str(exc)) from exc

        payload = build_ollama_payload(body.model_dump())
        try:
            upstream_response = call_upstream_ollama(config, payload)
        except Exception as exc:
            raise HTTPException(status_code=502, detail=f"Upstream Bielik error: {exc}") from exc
        return build_openai_response(upstream_response, body.model)

    return app


app = create_app()
