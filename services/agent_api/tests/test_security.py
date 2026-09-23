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
