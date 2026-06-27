import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from bielik_openai_proxy.app import (
    build_ollama_payload,
    build_openai_response,
    create_app,
    require_api_key,
)


class ProxyHelpersTest(unittest.TestCase):
    def test_build_ollama_payload_maps_messages_and_stream_flag(self):
        payload = build_ollama_payload(
            {
                "model": "bielik-test",
                "messages": [{"role": "user", "content": "Cześć"}],
                "stream": False,
            }
        )

        self.assertEqual(payload["model"], "bielik-test")
        self.assertEqual(payload["messages"][0]["content"], "Cześć")
        self.assertFalse(payload["stream"])

    def test_build_openai_response_wraps_ollama_message(self):
        response = build_openai_response(
            {
                "message": {"role": "assistant", "content": "Witaj"},
                "done_reason": "stop",
            },
            "bielik-test",
        )

        self.assertEqual(response["object"], "chat.completion")
        self.assertEqual(response["model"], "bielik-test")
        self.assertEqual(response["choices"][0]["message"]["content"], "Witaj")

    def test_require_api_key_accepts_valid_bearer_header(self):
        self.assertEqual(
            require_api_key("Bearer sekret", "sekret"),
            "sekret",
        )

    def test_require_api_key_rejects_invalid_header(self):
        with self.assertRaises(PermissionError):
            require_api_key("Bearer zly", "sekret")


class ProxyApiTest(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(
            create_app(
                {
                    "TRIAL_API_KEY": "sekret",
                    "UPSTREAM_MODEL_NAME": "bielik-test",
                    "UPSTREAM_LLM_URL": "https://bielik.internal",
                }
            )
        )

    def test_healthz_returns_ok(self):
        response = self.client.get("/healthz")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_models_requires_api_key(self):
        response = self.client.get("/v1/models")

        self.assertEqual(response.status_code, 401)

    @patch("bielik_openai_proxy.app.call_upstream_ollama")
    def test_chat_completion_calls_upstream_and_returns_openai_shape(self, mock_call_upstream):
        mock_call_upstream.return_value = {
            "message": {"role": "assistant", "content": "Odpowiedź testowa"},
            "done_reason": "stop",
        }

        response = self.client.post(
            "/v1/chat/completions",
            headers={"Authorization": "Bearer sekret"},
            json={
                "model": "bielik-test",
                "messages": [{"role": "user", "content": "Powiedz cześć"}],
                "stream": False,
            },
        )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["choices"][0]["message"]["content"], "Odpowiedź testowa")
        mock_call_upstream.assert_called_once()

    @patch("bielik_openai_proxy.app.call_upstream_ollama")
    def test_chat_completion_returns_502_when_upstream_fails(self, mock_call_upstream):
        mock_call_upstream.side_effect = RuntimeError("upstream timeout")

        response = self.client.post(
            "/v1/chat/completions",
            headers={"Authorization": "Bearer sekret"},
            json={
                "model": "bielik-test",
                "messages": [{"role": "user", "content": "Powiedz cześć"}],
                "stream": False,
            },
        )

        self.assertEqual(response.status_code, 502)
        self.assertIn("upstream timeout", response.json()["detail"])


if __name__ == "__main__":
    unittest.main()
