from app.config import setting


class GeminiWebProvider:
    """Explicitly opt-in experimental adapter; no CAPTCHA/2FA bypass or cookie export."""

    async def chat(self, message: str) -> str:
        if setting("GEMINI_WEB_ENABLED", "false").lower() != "true":
            raise RuntimeError("Gemini web automation is disabled. Use the official Gemini API or enable it explicitly.")
        raise RuntimeError(
            "Gemini web adapter is intentionally a safety-gated placeholder. "
            "Use an isolated user-approved browser session; never automate CAPTCHA or 2FA."
        )
