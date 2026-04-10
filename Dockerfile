# syntax=docker/dockerfile:1.7
# Multi-stage build using uv on a slim Python base.

# -----------------------------------------------------------------------------
# Stage 1: builder — install deps into a virtualenv
# -----------------------------------------------------------------------------
FROM python:3.12-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Install uv
COPY --from=ghcr.io/astral-sh/uv:0.5.11 /uv /uvx /usr/local/bin/

WORKDIR /app

# Copy lock files first for better layer caching
COPY pyproject.toml uv.lock* ./

# Install project dependencies into /app/.venv (no project code yet)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev || \
    uv sync --no-install-project --no-dev

# Copy project source (and README.md required by hatchling at build time)
# and install the package itself
COPY README.md ./
COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-dev

# -----------------------------------------------------------------------------
# Stage 2: runtime — minimal image with only the virtualenv + source
# -----------------------------------------------------------------------------
FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

RUN groupadd --system --gid 1000 app \
 && useradd --system --uid 1000 --gid app --home /app --shell /bin/bash app

WORKDIR /app

COPY --from=builder --chown=app:app /app/.venv /app/.venv
COPY --from=builder --chown=app:app /app/src /app/src

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request, sys; \
        sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3).status == 200 else 1)" \
        || exit 1

CMD ["uvicorn", "ai_workflow.main:app", "--host", "0.0.0.0", "--port", "8000"]
