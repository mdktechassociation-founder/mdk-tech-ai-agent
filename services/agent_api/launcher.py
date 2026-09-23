"""PyInstaller entry point for the bundled local MDK Agent backend."""
import os
from pathlib import Path

# Set packaged-mode defaults before importing the FastAPI app. Tool registries
# resolve the workspace from the environment when they are instantiated.
default_workspace = Path.home() / "Documents" / "MDK Agent Workspace"
default_workspace.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("MDK_AGENT_WORKSPACE", str(default_workspace))
# Packaged desktop builds expose host lifecycle controls only; computer-level
# automation is reserved for the isolated guest bridge.
os.environ.setdefault("MDK_AGENT_EXECUTION_TARGET", "sandbox")

import uvicorn  # noqa: E402

from app.main import app  # noqa: E402


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="warning")
