"""Application settings loaded from environment variables."""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the AI-Driven Workflow service."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
        # Docker Swarm mounts secrets under /run/secrets/<name>. pydantic-settings
        # reads each file as the matching field value. The directory is absent in
        # dev/tests and pydantic-settings simply skips it, so no fallback needed.
        secrets_dir="/run/secrets",
    )

    # App
    app_env: Literal["dev", "staging", "prod"] = "dev"
    app_log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    app_host: str = "0.0.0.0"
    app_port: int = 8000

    # Redis / queue
    redis_url: str = "redis://redis:6379/0"

    # Claude
    anthropic_api_key: str = Field(default="", repr=False)
    claude_budget_usd_per_job: float = 2.0

    # Linear
    linear_api_key: str = Field(default="", repr=False)
    linear_webhook_secret: str = Field(default="", repr=False)
    linear_team_id: str = ""

    # GitHub
    github_token: str = Field(default="", repr=False)
    github_webhook_secret: str = Field(default="", repr=False)
    github_repo_owner: str = "ODuo-Tech-Team"
    github_repo_name: str = ""

    # Observability
    otel_service_name: str = "ai-workflow"
    otel_exporter_otlp_endpoint: str = ""


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()
