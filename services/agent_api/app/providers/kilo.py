from typing import Any
import httpx
from app.config import secret, setting


class KiloProvider:
    """OpenAI-shaped Kilo Gateway client. Raw credentials never leave this class."""

    async def chat(self, messages: list[dict[str, Any]], tools: list[dict[str, Any]] | None = None) -> dict[str, Any]:
        base = setting("KILO_BASE_URL", "https://api.kilo.ai/api/gateway").rstrip("/")
        model = setting("KILO_MODEL", "kilo-auto/free")
        key = secret("KILO_API_KEY")
        headers = {"Content-Type": "application/json"}
        if key:
            headers["Authorization"] = f"Bearer {key}"
        payload: dict[str, Any] = {"model": model, "messages": messages, "temperature": 0.2}
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        async with httpx.AsyncClient(timeout=90) as client:
            response = await client.post(f"{base}/chat/completions", headers=headers, json=payload)
            response.raise_for_status()
            return response.json()
