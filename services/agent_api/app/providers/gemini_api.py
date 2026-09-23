from typing import Any
import httpx
from app.config import secret, setting


class GeminiApiProvider:
    """Official Gemini API adapter. The API key is injected only here."""

    async def chat(self, messages: list[dict[str, Any]]) -> str:
        key = secret("GEMINI_API_KEY")
        if not key:
            raise RuntimeError("GEMINI_API_KEY is not configured")
        model = setting("GEMINI_MODEL", "gemini-2.5-flash")
        contents = []
        for message in messages:
            role = "model" if message.get("role") == "assistant" else "user"
            contents.append({"role": role, "parts": [{"text": str(message.get("content", ""))}]})
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        async with httpx.AsyncClient(timeout=90) as client:
            response = await client.post(url, params={"key": key}, json={"contents": contents})
            response.raise_for_status()
            data = response.json()
        return data["candidates"][0]["content"]["parts"][0]["text"]
