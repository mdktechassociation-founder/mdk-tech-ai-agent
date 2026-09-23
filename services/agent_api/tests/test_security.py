from app.security.redaction import redact_text
from app.tools.registry import ToolRegistry


def test_common_tokens_are_redacted() -> None:
    value = "token " + "ghp_" + "abcdefghijklmnopqrstuvwxyz123456" + " and key " + "sk-" + "abcdefghijklmnopqrstuvwxyz123456"
    result = redact_text(value)
    assert "ghp_" not in result
    assert "sk-" not in result
    assert "[REDACTED]" in result


def test_tool_workspace_is_contained() -> None:
    tools = ToolRegistry()
    assert tools._path("README.md").is_relative_to(tools.workspace)
    try:
        tools._path("../../etc/passwd")
    except ValueError:
        pass
    else:
        raise AssertionError("path traversal was not rejected")


def test_sandbox_requires_exact_destroy_phrase() -> None:
    from app.sandbox import DESTRUCTION_PHRASE, SandboxManager

    manager = SandboxManager()
    try:
        manager.run("destroy", confirmation_phrase="wrong")
    except ValueError as exc:
        assert DESTRUCTION_PHRASE in str(exc)
    else:
        raise AssertionError("sandbox destruction did not require exact confirmation")


def test_sandbox_is_not_available_on_non_windows() -> None:
    import os
    from app.sandbox import SandboxManager

    if os.name != "nt":
        status = SandboxManager().status()
        assert status["supported"] is False


def test_guest_bridge_rejects_non_private_addresses() -> None:
    from app.guest import GuestBridge

    assert GuestBridge._private_ipv4("8.8.8.8") is None
    assert GuestBridge._private_ipv4("192.168.1.10") == "192.168.1.10"


def test_packaged_sandbox_target_routes_commands_to_guest(monkeypatch) -> None:
    import asyncio

    from app.tools.registry import ToolRegistry

    monkeypatch.setenv("MDK_AGENT_EXECUTION_TARGET", "sandbox")
    registry = ToolRegistry()
    registry.guest.run = lambda command: {"guest_command": command}  # type: ignore[method-assign]
    result = asyncio.run(registry.execute("run_command", {"command": "Get-Location"}, approved=True))
    assert result == {"guest_command": "Get-Location"}


def test_packaged_sandbox_target_blocks_host_workspace(monkeypatch) -> None:
    import asyncio

    from app.tools.registry import ToolRegistry

    monkeypatch.setenv("MDK_AGENT_EXECUTION_TARGET", "sandbox")
    registry = ToolRegistry()
    try:
        asyncio.run(registry.execute("workspace_read", {"path": "README.md"}))
    except RuntimeError as exc:
        assert "host fallback is disabled" in str(exc)
    else:
        raise AssertionError("sandbox mode unexpectedly used the host workspace")
