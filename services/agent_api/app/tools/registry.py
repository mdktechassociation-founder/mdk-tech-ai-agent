import asyncio
import os
import subprocess
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx

from app.config import setting, secret
from app.security.redaction import redact


class ToolApprovalRequired(Exception):
    def __init__(self, tool_name: str, arguments: dict[str, Any]):
        self.tool_name = tool_name
        self.arguments = arguments
        super().__init__(f"Approval required for {tool_name}")


class ToolRegistry:
    """Tools exposed to the model. Risky tools stop for human approval."""

    def __init__(self) -> None:
        configured = Path(setting("MDK_AGENT_WORKSPACE", "../../")).expanduser()
        self.workspace = configured.resolve()

    def schemas(self) -> list[dict[str, Any]]:
        return [
            {
                "type": "function",
                "function": {
                    "name": "workspace_list",
                    "description": "List files in the project workspace. Read-only.",
                    "parameters": {"type": "object", "properties": {"subdir": {"type": "string"}}, "additionalProperties": False},
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "workspace_read",
                    "description": "Read a UTF-8 text file in the project workspace. Read-only.",
                    "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"], "additionalProperties": False},
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "git_status",
                    "description": "Show current Git status. Read-only.",
                    "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "workspace_write",
                    "description": "Write a text file in the workspace. Requires human approval.",
                    "parameters": {"type": "object", "properties": {"path": {"type": "string"}, "content": {"type": "string"}}, "required": ["path", "content"], "additionalProperties": False},
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "run_command",
                    "description": "Run a command in the workspace. Requires human approval.",
                    "parameters": {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"], "additionalProperties": False},
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "git_commit",
                    "description": "Create a Git commit. Requires human approval.",
                    "parameters": {"type": "object", "properties": {"message": {"type": "string"}}, "required": ["message"], "additionalProperties": False},
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "git_push",
                    "description": "Push the current branch. Requires human approval.",
                    "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "generate_image",
                    "description": "Generate an image through Pollinations. Do not include secrets or private data. Requires human approval.",
                    "parameters": {"type": "object", "properties": {"prompt": {"type": "string"}, "filename": {"type": "string"}}, "required": ["prompt", "filename"], "additionalProperties": False},
                },
            },
        ]

    @staticmethod
    def requires_approval(name: str) -> bool:
        return name in {"workspace_write", "run_command", "git_commit", "git_push", "generate_image"}

    def _path(self, raw: str) -> Path:
        candidate = (self.workspace / raw).resolve()
        try:
            candidate.relative_to(self.workspace)
        except ValueError as exc:
            raise ValueError("Path is outside the approved workspace") from exc
        return candidate

    async def execute(self, name: str, arguments: dict[str, Any], approved: bool = False) -> dict[str, Any]:
        if self.requires_approval(name) and not approved:
            raise ToolApprovalRequired(name, arguments)
        if name == "workspace_list":
            return await asyncio.to_thread(self._list, arguments.get("subdir", "."))
        if name == "workspace_read":
            return await asyncio.to_thread(self._read, arguments["path"])
        if name == "git_status":
            return await asyncio.to_thread(self._git_status)
        if name == "workspace_write":
            return await asyncio.to_thread(self._write, arguments["path"], arguments["content"])
        if name == "run_command":
            return await asyncio.to_thread(self._command, arguments["command"])
        if name == "git_commit":
            return await asyncio.to_thread(self._commit, arguments["message"])
        if name == "git_push":
            return await asyncio.to_thread(self._push)
        if name == "generate_image":
            return await self._image(arguments["prompt"], arguments["filename"])
        raise ValueError(f"Unknown tool: {name}")

    def _list(self, subdir: str) -> dict[str, Any]:
        root = self._path(subdir)
        items = []
        for path in sorted(root.rglob("*")):
            if any(part in {".git", ".venv", "node_modules", "build", ".dart_tool"} for part in path.parts):
                continue
            if path.is_file():
                items.append(str(path.relative_to(self.workspace)))
            if len(items) >= 500:
                break
        return {"files": items}

    def _read(self, raw: str) -> dict[str, Any]:
        path = self._path(raw)
        if path.stat().st_size > 200_000:
            raise ValueError("File is too large for the read tool")
        return {"path": raw, "content": path.read_text(encoding="utf-8")}

    def _git_status(self) -> dict[str, Any]:
        result = subprocess.run(["git", "status", "--short", "--branch"], cwd=self.workspace, capture_output=True, text=True, timeout=30)
        return {"exit_code": result.returncode, "output": result.stdout[-20_000:]}

    def _write(self, raw: str, content: str) -> dict[str, Any]:
        path = self._path(raw)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return {"written": raw, "bytes": len(content.encode("utf-8"))}

    def _command(self, command: str) -> dict[str, Any]:
        # Exact command is shown in the approval card before this method runs.
        result = subprocess.run(command, cwd=self.workspace, shell=True, capture_output=True, text=True, timeout=120, env=os.environ.copy())
        return {"exit_code": result.returncode, "stdout": redact(result.stdout[-20_000:]), "stderr": redact(result.stderr[-20_000:])}

    def _commit(self, message: str) -> dict[str, Any]:
        result = subprocess.run(["git", "add", "-A"], cwd=self.workspace, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            return {"exit_code": result.returncode, "stderr": result.stderr}
        result = subprocess.run(["git", "commit", "-m", message[:120]], cwd=self.workspace, capture_output=True, text=True, timeout=60)
        return {"exit_code": result.returncode, "output": redact((result.stdout + result.stderr)[-20_000:])}

    def _push(self) -> dict[str, Any]:
        result = subprocess.run(["git", "push"], cwd=self.workspace, capture_output=True, text=True, timeout=120)
        return {"exit_code": result.returncode, "output": redact((result.stdout + result.stderr)[-20_000:])}

    async def _image(self, prompt: str, filename: str) -> dict[str, Any]:
        safe_name = Path(filename).name
        path = self._path(f"assets/{safe_name}")
        url = f"https://image.pollinations.ai/prompt/{quote(prompt)}"
        headers = {}
        key = secret("POLLINATIONS_API_KEY")
        if key:
            headers["Authorization"] = f"Bearer {key}"
        async with httpx.AsyncClient(timeout=120, follow_redirects=True) as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(response.content)
        return {"saved": str(path.relative_to(self.workspace)), "bytes": len(response.content)}
