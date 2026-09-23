from app.config import secret


_ALLOWED_SECRET_REFS = {
    "KILO_API_KEY",
    "GEMINI_API_KEY",
    "POLLINATIONS_API_KEY",
    "GITHUB_TOKEN",
}


def resolve_secret_ref(ref: str) -> str:
    """Backend-only secret lookup. Never register this as an agent tool."""
    if ref not in _ALLOWED_SECRET_REFS:
        raise ValueError("Unknown credential reference")
    return secret(ref)
