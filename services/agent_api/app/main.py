from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.agent.orchestrator import approve, run_task
from app.config import setting
from app.schemas import AgentRequest, ApprovalRequest

app = FastAPI(title="MDK Agent API", version="0.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://127.0.0.1", "http://localhost:8000", "http://127.0.0.1:8000"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "mdk-agent-api", "version": "0.2.0"}


@app.get("/api/agent/config")
async def public_config() -> dict[str, str | bool]:
    # Metadata only. Never expose credentials or secret file contents.
    return {
        "model": setting("KILO_MODEL", "kilo-auto/free"),
        "gemini_web_enabled": setting("GEMINI_WEB_ENABLED", "false").lower() == "true",
        "secrets_loaded": bool(setting("KILO_API_KEY") or setting("GEMINI_API_KEY")),
    }


@app.post("/api/agent/run")
async def run(request: AgentRequest) -> dict:
    return await run_task(request.message, request.session_id)


@app.post("/api/agent/approve")
async def approve_action(request: ApprovalRequest) -> dict:
    return await approve(request.approval_id, request.approved)
