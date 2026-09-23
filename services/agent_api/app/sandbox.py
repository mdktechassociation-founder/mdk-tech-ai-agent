"""Safe host-side lifecycle broker for the isolated Windows guest.

This module intentionally does not expose arbitrary host PowerShell. It can only
invoke the checked-in Hyper-V lifecycle script with a fixed action allowlist.
Guest application automation belongs in the guest agent, not in this host broker.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


DESTRUCTION_PHRASE = "DESTROY MDK AGENT VM"
_ALLOWED_ACTIONS = {"status", "create", "start", "stop", "destroy"}


def _script_path() -> Path:
    override = os.getenv("MDK_AGENT_SANDBOX_SCRIPT")
    if override:
        return Path(override).expanduser().resolve()
    if getattr(sys, "frozen", False):
        # The backend is installed under <app>\\backend and the lifecycle
        # script is installed under <app>\\sandbox.
        return Path(sys.executable).resolve().parent.parent / "sandbox" / "MDK-Agent-Sandbox.ps1"
    # Development layout: repo/sandbox/MDK-Agent-Sandbox.ps1.
    return Path(__file__).resolve().parents[3] / "sandbox" / "MDK-Agent-Sandbox.ps1"


def _powershell() -> str:
    return os.getenv("MDK_AGENT_POWERSHELL", "powershell.exe" if os.name == "nt" else "powershell")


class SandboxManager:
    """Run fixed Hyper-V lifecycle actions without arbitrary host execution."""

    def __init__(self) -> None:
        self.script = _script_path()

    def status(self) -> dict[str, Any]:
        if os.name != "nt":
            return {
                "mode": "hyperv-isolated-guest",
                "supported": False,
                "vm_exists": False,
                "vm_state": "Unavailable",
                "managed_data_exists": False,
                "message": "The isolated Windows guest is available only on Windows.",
            }
        return self._run("status")

    def run(
        self,
        action: str,
        *,
        iso_path: str = "",
        confirmation_phrase: str = "",
    ) -> dict[str, Any]:
        if action not in _ALLOWED_ACTIONS:
            raise ValueError("Unsupported sandbox lifecycle action")
        if action == "destroy" and confirmation_phrase != DESTRUCTION_PHRASE:
            raise ValueError(f"Destruction requires the exact confirmation phrase: {DESTRUCTION_PHRASE}")
        if action == "create":
            if not iso_path:
                raise ValueError("A Windows ISO path is required to create the isolated guest")
            iso = Path(iso_path).expanduser().resolve()
            if not iso.is_file() or iso.suffix.lower() != ".iso":
                raise ValueError("The ISO path must point to an existing .iso file")
            iso_path = str(iso)
        if os.name != "nt":
            return {
                "mode": "hyperv-isolated-guest",
                "supported": False,
                "action": action,
                "message": "Sandbox lifecycle actions require Windows with Hyper-V.",
            }
        return self._run(action, iso_path=iso_path, confirmation_phrase=confirmation_phrase)

    def _run(self, action: str, *, iso_path: str = "", confirmation_phrase: str = "") -> dict[str, Any]:
        if not self.script.is_file():
            raise RuntimeError("The MDK Agent sandbox lifecycle script is not installed")
        command = [
            _powershell(),
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(self.script),
            "-Action",
            action,
        ]
        if iso_path:
            command.extend(["-IsoPath", iso_path])
        if confirmation_phrase:
            command.extend(["-ConfirmationPhrase", confirmation_phrase])
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
        output = (completed.stdout or "").strip().splitlines()
        payload: dict[str, Any] = {}
        if output:
            try:
                payload = json.loads(output[-1])
            except json.JSONDecodeError:
                payload = {"output": output[-1][-2000:]}
        if completed.returncode != 0:
            detail = (completed.stderr or completed.stdout or "Sandbox lifecycle action failed").strip()
            raise RuntimeError(detail[-2000:])
        return payload or {"action": action, "status": "completed"}
