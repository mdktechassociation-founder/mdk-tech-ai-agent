from app.config import setting


class GeminiWebProvider:
    """Optional experimental browser adapter.

    It requires a user-approved, isolated browser profile that is already signed
    in. It does not automate login, CAPTCHA, 2FA, cookie export, or quota bypass.
    Playwright is an optional dependency and the adapter is disabled by default.
    """

    async def chat(self, message: str) -> str:
        if setting("GEMINI_WEB_ENABLED", "false").lower() != "true":
            raise RuntimeError("Gemini web automation is disabled")
        profile = setting("GEMINI_WEB_PROFILE_DIR")
        if not profile:
            raise RuntimeError("GEMINI_WEB_PROFILE_DIR is not configured")
        try:
            from playwright.async_api import async_playwright
        except ImportError as exc:
            raise RuntimeError("Install optional Playwright dependencies to enable Gemini web") from exc

        async with async_playwright() as playwright:
            context = await playwright.chromium.launch_persistent_context(
                profile,
                headless=True,
                accept_downloads=False,
            )
            try:
                page = await context.new_page()
                await page.goto("https://gemini.google.com/app", wait_until="domcontentloaded", timeout=60_000)
                if "accounts.google.com" in page.url:
                    raise RuntimeError("Gemini session is not authenticated; complete login manually in the isolated profile")
                editor = page.locator("textarea").first
                if await editor.count() == 0:
                    editor = page.locator("[contenteditable='true']").first
                await editor.fill(message)
                await editor.press("Enter")
                await page.wait_for_timeout(3_000)
                responses = page.locator("[data-message-author-role='model']")
                if await responses.count() == 0:
                    raise RuntimeError("Gemini web response selector changed or no response was returned")
                return await responses.last.inner_text()
            finally:
                await context.close()
