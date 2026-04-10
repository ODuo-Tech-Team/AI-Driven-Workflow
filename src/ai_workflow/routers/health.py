"""Health probes used by Docker, Traefik, and CI smoke tests."""

from __future__ import annotations

from fastapi import APIRouter

from ai_workflow import __version__

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, str]:
    """Liveness probe. Always returns 200 when the process is up."""
    return {"status": "ok", "version": __version__}


@router.get("/ready")
async def ready() -> dict[str, str]:
    """Readiness probe.

    Phase 0 returns ok unconditionally. Later phases check Redis, Linear,
    and GitHub connectivity before reporting ready.
    """
    return {"status": "ready"}
