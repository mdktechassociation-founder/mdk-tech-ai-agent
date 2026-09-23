import os
from pathlib import Path
from dotenv import dotenv_values

DEFAULT_SECRET_FILE = Path.home() / ".config" / "mdk-tech-ai-agent" / "secrets.env"


def _values() -> dict[str, str]:
    path = Path(os.getenv("MDK_AGENT_SECRETS_FILE", str(DEFAULT_SECRET_FILE))).expanduser()
    values = {k: v for k, v in dotenv_values(path).items() if v is not None}
    # Process environment wins over the file for CI/production injection.
    values.update({k: v for k, v in os.environ.items() if v is not None})
    return values


def setting(name: str, default: str = "") -> str:
    return _values().get(name, default)


def secret(name: str) -> str:
    # This function is backend-only. It is never exposed as an agent tool.
    return setting(name, "")
