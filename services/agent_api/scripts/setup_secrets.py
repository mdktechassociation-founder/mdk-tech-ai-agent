"""Create the local MDK Agent secret file without echoing values."""
from getpass import getpass
from pathlib import Path
import os
import stat

SECRET_PATH = Path(os.environ.get(
    "MDK_AGENT_SECRETS_FILE",
    Path.home() / ".config" / "mdk-tech-ai-agent" / "secrets.env",
)).expanduser()

FIELDS = [
    ("KILO_API_KEY", "Kilo API key (optional for eligible free models)"),
    ("GEMINI_API_KEY", "Official Gemini API key (optional)"),
    ("POLLINATIONS_API_KEY", "Pollinations secret key (optional)"),
    ("MDK_AGENT_GUEST_TOKEN", "Isolated guest bridge token (optional)"),
]


def main() -> None:
    print("MDK Agent secure setup")
    print("Values are hidden and will be saved outside the Git repository.")
    print("Press Enter to leave an optional value empty.\n")

    values: dict[str, str] = {}
    for name, label in FIELDS:
        values[name] = getpass(f"{label}: ")

    SECRET_PATH.parent.mkdir(parents=True, exist_ok=True)
    SECRET_PATH.write_text(
        "# Local-only MDK Agent secrets. Never commit this file.\n"
        + "".join(f"{name}={value}\n" for name, value in values.items()),
        encoding="utf-8",
    )
    SECRET_PATH.chmod(stat.S_IRUSR | stat.S_IWUSR)
    print(f"\nSaved secure secret references to: {SECRET_PATH}")
    print("Secret values were not printed, committed, or sent to the model.")


if __name__ == "__main__":
    main()
