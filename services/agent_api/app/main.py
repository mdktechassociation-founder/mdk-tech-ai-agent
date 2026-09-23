from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from app.agent.orchestrator import run_task
from app.config import setting

app = FastAPI(title="MDK Agent API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://127.0.0.1", "http://localhost:8000", "http://127.0.0.1:8000"],
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


class AgentRequest(BaseModel):
    message: str = Field(min_length=1, max_length=20000)
    session_id: str = Field(default="desktop-default", max_length=128)


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "mdk-agent-api"}


@app.get("/api/agent/config")
async def public_config() -> dict[str, str | bool]:
    # Deliberately exposes metadata only, never credentials.
    return {
        "model": setting("KILO_MODEL", "kilo-auto/free"),
        "gemini_web_enabled": setting("GEMINI_WEB_ENABLED", "false").lower() == "true",
        "secrets_loaded": bool(setting("KILO_API_KEY") or setting("GEMINI_API_KEY")),
    }


@app.post("/api/agent/run")
async def run(request: AgentRequest) -> dict:
    return await run_task(request.message)
