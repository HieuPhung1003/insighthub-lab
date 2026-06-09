"""
Minimal health-endpoint tests — no database or Redis required.
Imports only the health router, bypassing the DB connection pool entirely.
"""
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.routers.health import router

# Isolated app: just the health router, no lifespan that opens a DB pool
_app = FastAPI()
_app.include_router(router)
client = TestClient(_app)


def test_liveness_returns_ok():
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_liveness_content_type_json():
    resp = client.get("/healthz")
    assert "application/json" in resp.headers["content-type"]


def test_unknown_route_returns_404():
    resp = client.get("/does-not-exist")
    assert resp.status_code == 404
