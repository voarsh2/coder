# Custom Dockerfile for Coder with license checking disabled
# This Dockerfile is based on the official Coder Dockerfile but includes
# all the necessary components to build a complete custom image

ARG BASE_IMAGE=ghcr.io/coder/coder-base:latest
FROM $BASE_IMAGE

# LABEL doesn't add any real layers so it's fine (and easier) to do it here than
# in the build script.
ARG CODER_VERSION
LABEL \
    org.opencontainers.image.title="Coder (Custom)" \
    org.opencontainers.image.description="A custom build of Coder with license checking disabled" \
    org.opencontainers.image.url="https://github.com/coder/coder" \
    org.opencontainers.image.source="https://github.com/coder/coder" \
    org.opencontainers.image.version="$CODER_VERSION" \
    org.opencontainers.image.vendor="Custom Build" \
    custom.license.checking="disabled"

# The coder binary is injected by the build script
COPY --chown=1000:1000 --chmod=755 coder /opt/coder

# Create a non-root user (if it doesn't exist)
RUN if ! id -u coder >/dev/null 2>&1; then \
        addgroup -g 1000 -S coder && \
        adduser -u 1000 -S coder -G coder; \
    fi

# Set ownership of the binary
RUN chown coder:coder /opt/coder

# Switch to the non-root user
USER coder

# Expose the default Coder port
EXPOSE 3000

# Set the entrypoint
ENTRYPOINT ["/opt/coder", "server"]
