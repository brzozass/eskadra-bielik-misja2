import json
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from bielik_openai_proxy.app import (
    build_ollama_payload,
    build_openai_response,
    create_app,
    parse_ollama_response,
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


class ParseOllamaResponseTest(unittest.TestCase):
    """Tests for parse_ollama_response — handles single JSON and NDJSON."""

    def _make_response(self, text: str):
        from unittest.mock import MagicMock
        resp = MagicMock()
        resp.text = text
        resp.json.side_effect = lambda: json.loads(text)
        return resp

    def test_single_json_response(self):
        """Normal non-stream response — single JSON object."""
        resp = self._make_response(
            json.dumps({"message": {"content": "hello"}, "done": True})
        )
        result = parse_ollama_response(resp)
        self.assertEqual(result["message"]["content"], "hello")
        self.assertTrue(result["done"])

    def test_ndjson_stream_response(self):
        """NDJSON with multiple chunks — should return last done chunk."""
        ndjson = "\n".join([
            json.dumps({"message": {"content": "Wit"}, "done": False}),
            json.dumps({"message": {"content": "aj"}, "done": False}),
            json.dumps({"message": {"content": ""}, "done": True, "done_reason": "stop"}),
        ])
        resp = self._make_response(ndjson)
        result = parse_ollama_response(resp)
        self.assertTrue(result["done"])
        self.assertEqual(result["done_reason"], "stop")

    def test_ndjson_no_done_chunk_merges_content(self):
        """Edge case: no done=True chunk — should merge all content."""
        ndjson = "\n".join([
            json.dumps({"message": {"content": "Hello"}, "done": False}),
            json.dumps({"message": {"content": " world"}, "done": False}),
        ])
        resp = self._make_response(ndjson)
        result = parse_ollama_response(resp)
        self.assertEqual(result["message"]["content"], "Hello world")


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


class ChatCompletionStreamingTest(unittest.TestCase):
    """Tests for SSE streaming path (stream:true)."""

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

    def _parse_sse_events(self, body: str) -> list[str]:
        events = []
        for raw in body.split("\n\n"):
            line = raw.strip()
            if not line.startswith("data:"):
                continue
            events.append(line[len("data:"):].strip())
        return events

    def _fake_upstream_response(self, ndjson_lines: list[str]):
        from unittest.mock import MagicMock
        ctx = MagicMock()
        ctx.iter_lines.return_value = iter(ndjson_lines)
        ctx.raise_for_status.return_value = None
        cm = MagicMock()
        cm.__enter__.return_value = ctx
        cm.__exit__.return_value = False
        return cm

    @patch("bielik_openai_proxy.app.fetch_google_bearer_token", return_value="fake-token")
    @patch("bielik_openai_proxy.app.requests.post")
    def test_chat_completion_streaming_returns_sse_chunks(self, mock_post, _mock_token):
        ndjson = [
            json.dumps({"message": {"role": "assistant", "content": "Wit"}, "done": False}),
            json.dumps({"message": {"role": "assistant", "content": "aj"}, "done": False}),
            json.dumps({"message": {"role": "assistant", "content": ""}, "done": True, "done_reason": "stop"}),
        ]
        mock_post.return_value = self._fake_upstream_response(ndjson)

        response = self.client.post(
            "/v1/chat/completions",
            headers={"Authorization": "Bearer sekret"},
            json={
                "model": "bielik-test",
                "messages": [{"role": "user", "content": "Powiedz cześć"}],
                "stream": True,
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.headers["content-type"].startswith("text/event-stream"))

        events = self._parse_sse_events(response.text)
        self.assertGreaterEqual(len(events), 4)
        self.assertEqual(events[-1], "[DONE]")

        json_events = [json.loads(e) for e in events[:-1]]
        self.assertEqual(json_events[0]["choices"][0]["delta"], {"role": "assistant"})
        content_chunks = [
            e for e in json_events
            if e["choices"][0]["delta"].get("content")
        ]
        merged = "".join(e["choices"][0]["delta"]["content"] for e in content_chunks)
        self.assertEqual(merged, "Witaj")

        final_chunk = json_events[-1]
        self.assertEqual(final_chunk["choices"][0]["finish_reason"], "stop")
        self.assertEqual(final_chunk["choices"][0]["delta"], {})

        mock_post.assert_called_once()
        sent_payload = mock_post.call_args.kwargs["json"]
        self.assertTrue(sent_payload["stream"])

    @patch("bielik_openai_proxy.app.fetch_google_bearer_token", return_value="fake-token")
    @patch("bielik_openai_proxy.app.requests.post")
    def test_chat_completion_streaming_emits_done_on_upstream_error(self, mock_post, _mock_token):
        mock_post.side_effect = RuntimeError("upstream exploded")

        response = self.client.post(
            "/v1/chat/completions",
            headers={"Authorization": "Bearer sekret"},
            json={
                "model": "bielik-test",
                "messages": [{"role": "user", "content": "Powiedz cześć"}],
                "stream": True,
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.headers["content-type"].startswith("text/event-stream"))

        events = self._parse_sse_events(response.text)
        self.assertEqual(events[-1], "[DONE]")

        json_events = [json.loads(e) for e in events[:-1]]
        error_chunks = [
            e for e in json_events
            if e["choices"][0].get("finish_reason") == "error"
        ]
        self.assertEqual(len(error_chunks), 1)
        self.assertIn("upstream exploded", error_chunks[0]["choices"][0]["delta"]["content"])

    def test_chat_completion_streaming_requires_api_key(self):
        response = self.client.post(
            "/v1/chat/completions",
            json={
                "model": "bielik-test",
                "messages": [{"role": "user", "content": "Hi"}],
                "stream": True,
            },
        )
        self.assertEqual(response.status_code, 401)


if __name__ == "__main__":
    unittest.main()
