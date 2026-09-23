import os
import stat
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


_ALLOWED_LOCAL_SECRET_NAMES = {
    "KILO_API_KEY",
    "GEMINI_API_KEY",
    "POLLINATIONS_API_KEY",
    "MDK_AGENT_GUEST_TOKEN",
}


def save_local_secret(name: str, value: str) -> None:
    """Save one local-only secret without returning or logging its value."""
    if name not in _ALLOWED_LOCAL_SECRET_NAMES:
        raise ValueError("Unsupported local secret name")
    if not value or "\r" in value or "\n" in value:
        raise ValueError("Local secret values must be a single non-empty line")
    path = Path(os.getenv("MDK_AGENT_SECRETS_FILE", str(DEFAULT_SECRET_FILE))).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text(encoding="utf-8") if path.exists() else ""
    lines = existing.splitlines()
    replacement = f"{name}={value}"
    found = False
    updated: list[str] = []
    for line in lines:
        if line.startswith(f"{name}="):
            updated.append(replacement)
            found = True
        else:
            updated.append(line)
    if not found:
        updated.append(replacement)
    path.write_text("\n".join(updated).rstrip() + "\n", encoding="utf-8")
    try:
        path.chmod(stat.S_IRUSR | stat.S_IWUSR)
    except OSError:
        # Windows ACLs inherit from the user's profile directory.
        pass
