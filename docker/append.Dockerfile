
# --- appended by sub2api-patched (.github/workflows/build.yml) ---
# The official release image (Dockerfile.goreleaser) ships curl and health-checks with it; the
# source Dockerfile built here does neither. /app stays owned by root on purpose: sub2api's online
# update writes the official binary into /app, which would silently drop the patches. This second
# HEALTHCHECK replaces the one above it (`docker build --check` warns about that; it is intended).
RUN apk add --no-cache curl
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${SERVER_PORT:-8080}/health || exit 1
