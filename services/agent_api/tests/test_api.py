from fastapi.testclient import TestClient
from app.main import app


def test_health() -> None:
    client = TestClient(app)
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_config_does_not_expose_secrets() -> None:
    client = TestClient(app)
    data = client.get("/api/agent/config").json()
    assert "KILO_API_KEY" not in str(data)
    assert "GEMINI_API_KEY" not in str(data)


def test_sandbox_status_is_safe_metadata_only() -> None:
    client = TestClient(app)
    response = client.get("/api/sandbox/status")
    assert response.status_code == 200
    data = response.json()
    assert "KILO_API_KEY" not in str(data)
    assert "GEMINI_API_KEY" not in str(data)


def test_sandbox_destroy_requires_exact_phrase() -> None:
    client = TestClient(app)
    response = client.post("/api/sandbox/action", json={"action": "destroy"})
    assert response.status_code == 200
    assert response.json()["status"] == "confirmation_required"
