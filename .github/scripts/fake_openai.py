"""Tiny stand-in for the OpenAI Chat Completions API, used by the simulator smoke test.

Records every request body to requests.jsonl and answers with a reply that echoes the
listener's last message, so screenshots prove the app's words came from this "AI".
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

LOG = sys.argv[2] if len(sys.argv) > 2 else "requests.jsonl"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        try:
            body = json.loads(raw)
        except ValueError:
            body = {"unparsed": raw.decode(errors="replace")}
        record = {"path": self.path, "authorization": self.headers.get("Authorization", ""), "body": body}
        with open(LOG, "a") as log:
            log.write(json.dumps(record) + "\n")

        messages = body.get("messages", []) if isinstance(body, dict) else []
        last_user = next((m.get("content", "") for m in reversed(messages) if m.get("role") == "user"), "")
        reply = f"FAKE-AI heard: {last_user[:60]}… breathe slowly now."
        payload = json.dumps({
            "id": "test",
            "object": "chat.completion",
            "choices": [{"index": 0, "message": {"role": "assistant", "content": reply}, "finish_reason": "stop"}],
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
