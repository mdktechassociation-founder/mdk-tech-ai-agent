"""Authenticated command bridge to the isolated guest, never to the host."""
from __future__ import annotations

import ipaddress
import json
import urllib.error
import urllib.request
from typing import Any

from app.config import setting
from app.sandbox import SandboxManager


class GuestBridge:
    def __init__(self, sandbox: SandboxManager) -> None:
        self.sandbox = sandbox

    def run(self, command: str) -> dict[str, Any]:
        if not command or len(command) > 20_000:
            raise ValueError("Guest command must be between 1 and 20000 characters")
        token = setting("MDK_AGENT_GUEST_TOKEN", "")
        if not token:
            raise RuntimeError("The isolated guest bridge token is not configured in the backend secret file")
        status = self.sandbox.status()
        addresses = status.get("ip_addresses", [])
        ip = next((self._private_ipv4(item) for item in addresses if self._private_ipv4(item)), None)
        if not ip:
            raise RuntimeError("The isolated guest is not running or has no private IPv4 address")
        payload = json.dumps({"command": command}).encode("utf-8")
        request = urllib.request.Request(
            f"http://{ip}:8765/run",
            data=payload,
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=130) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Guest bridge returned HTTP {exc.code}: {detail[:500]}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError("The isolated guest bridge is unreachable") from exc

    @staticmethod
    def _private_ipv4(value: Any) -> str | None:
        try:
            address = ipaddress.ip_address(str(value))
        except ValueError:
            return None
        if address.version == 4 and (address.is_private or address.is_loopback):
            return str(address)
        return None
