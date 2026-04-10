"""FastAPI application entrypoint with lifespan-managed resources."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from ai_workflow import __version__
from ai_workflow.config import get_settings
from ai_workflow.routers import health

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Initialize and tear down long-lived resources.

    Phase 0 keeps this minimal. Later phases attach Redis/RQ connection pools,
    HTTP clients for Linear/GitHub, and Claude Agent SDK session state here.
    """
    settings = get_settings()
    logging.basicConfig(level=settings.app_log_level)
    logger.info(
        "ai-workflow starting",
        extra={"env": settings.app_env, "version": __version__},
    )
    try:
        yield
    finally:
        logger.info("ai-workflow shutting down")


def create_app() -> FastAPI:
    """Application factory."""
    app = FastAPI(
        title="AI-Driven Workflow",
        version=__version__,
        description=(
            "Orquestrador de 3 agentes Claude (PM, Executor, Reviewer) ligando Linear + GitHub."
        ),
        lifespan=lifespan,
    )
    app.include_router(health.router)
    return app


app = create_app()
