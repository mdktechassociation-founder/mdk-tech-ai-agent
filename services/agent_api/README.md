# MDK Agent API

FastAPI backend for the Arena-style Flutter desktop client.

## Secure first-time setup

Create a secret file outside the repository:

```bash
mkdir -p ~/.config/mdk-tech-ai-agent
cp .env.example ~/.config/mdk-tech-ai-agent/secrets.env
chmod 600 ~/.config/mdk-tech-ai-agent/secrets.env
```

Edit the secret file locally. Do not paste secrets into chat, commit them, or place them in Flutter code.

The backend reads the file through `MDK_AGENT_SECRETS_FILE` or the default path above. It exposes provider metadata only; it never exposes raw secret values to the Flutter client.

## Run

```bash
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

The first milestone uses Kilo as the provider adapter and returns a safe response if no provider is configured. Workspace, web, Git, image, and browser tools will be added behind approval gates.

Gemini Playwright remains disabled by default. Do not automate CAPTCHA, 2FA, or login bypass. Tor is not used to evade provider quotas or rate limits.

## First-time secret setup

From the repository root:

```bash
python services/agent_api/scripts/setup_secrets.py
```

The prompts are hidden. The file is written to `~/.config/mdk-tech-ai-agent/secrets.env` with owner-only permissions. This command does not print key values.
