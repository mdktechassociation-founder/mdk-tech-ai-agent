from pydantic import BaseModel, Field


class AgentRequest(BaseModel):
    message: str = Field(min_length=1, max_length=20000)
    session_id: str = Field(default="desktop-default", max_length=128)


class ApprovalRequest(BaseModel):
    approval_id: str = Field(min_length=8, max_length=128)
    approved: bool


class SandboxRequest(BaseModel):
    action: str = Field(pattern=r"^(status|create|start|stop|destroy)$")
    iso_path: str = Field(default="", max_length=2048)
    confirmation_phrase: str = Field(default="", max_length=64)
