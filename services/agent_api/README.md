# MDK Agent API

FastAPI agent controller for the Arena-style Flutter Windows client.

## What is implemented

- Kilo OpenAI-compatible provider adapter
- Plan → tool-call → result → verify loop
- Read-only workspace and Git status tools
- Approval-gated file writes, shell commands, image generation, commits, and pushes
- Secret-safe provider boundary
- Optional official Gemini API adapter
- Experimental Gemini Playwright adapter, disabled by default
- No CAPTCHA/2FA automation and no quota/rate-limit bypass

## Secure first-time setup

From the repository root:

```bash
python services/agent_api/scripts/setup_secrets.py
```

The hidden prompts save to `~/.config/mdk-tech-ai-agent/secrets.env` with owner-only permissions. The file is outside Git and is never returned by an API endpoint.

## Run locally

```bash
cd services/agent_api
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Optional development checks:

```bash
pip install -r requirements-dev.txt
pytest -q
ruff check app tests
```

## Provider notes

- `KILO_MODEL=kilo-auto/free` can work without a key for eligible free models; free providers can log prompts and availability changes.
- `GEMINI_API_KEY` is for the official API adapter.
- `GEMINI_WEB_ENABLED=false` by default. Enabling browser automation requires a user-approved isolated profile and optional Playwright installation.
- `POLLINATIONS_API_KEY` is injected only by the image tool. Never send secret or private prompts to anonymous image endpoints.
