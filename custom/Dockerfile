# Multi-stage Dockerfile for building Coder with license checking disabled
# This Dockerfile builds both the Go binary and the final Docker image

# Build stage for frontend
FROM node:20-alpine AS frontend-builder

# Install pnpm
RUN npm install -g pnpm

# Set working directory
WORKDIR /src/site

# Copy package files
COPY site/package*.json site/pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy site source
COPY site/ ./

# Build the frontend
RUN pnpm build

# Build stage for Go binary
FROM golang:1.24-alpine AS go-builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /src

# Set build arguments
ARG VERSION
ARG ARCH=amd64

# Set Go environment variables
ENV GOOS=linux
ENV GOARCH=$ARCH
ENV CGO_ENABLED=0

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Copy the frontend from the frontend builder stage
COPY --from=frontend-builder /src/site/out ./site/out

# Build agent binaries from source
RUN mkdir -p /src/site/out/bin && \
    for arch in amd64 arm64 arm; do \
        export GOOS=linux GOARCH=$arch CGO_ENABLED=0; \
        if [ "$arch" = "arm" ]; then export GOARM=7; fi; \
        go build -tags "embed" -buildvcs=false \
            -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=${VERSION} -s -w" \
            -o "/src/site/out/bin/coder-linux-$arch" \
            ./enterprise/cmd/coder; \
    done && \
    if [ -f "/src/site/out/bin/coder-linux-arm" ]; then \
        mv "/src/site/out/bin/coder-linux-arm" "/src/site/out/bin/coder-linux-armv7"; \
    fi && \
    echo "Downloading Windows binary from GitHub releases..." && \
    DOWNLOAD_VERSION=$(echo "${VERSION}" | sed 's/-devel+.*//') && \
    echo "Downloading Windows binary for version: ${DOWNLOAD_VERSION}" && \
    wget -O "/tmp/coder-windows.zip" "https://github.com/coder/coder/releases/download/v${DOWNLOAD_VERSION}/coder_${DOWNLOAD_VERSION}_windows_amd64.zip" && \
    cd /tmp && \
    unzip -j "coder-windows.zip" "coder.exe" && \
    mv "coder.exe" "/src/site/out/bin/coder-windows-amd64.exe" && \
    cd /src/site/out/bin && \
    openssl dgst -r -sha1 coder-* | tee coder.sha1


# Build the Go binary with embed tag
RUN go build -tags "embed" \
    -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=$VERSION -s -w" \
    -o /opt/coder \
    ./enterprise/cmd/coder && \
    chmod +x /opt/coder

# Final stage
FROM ghcr.io/coder/coder-base:latest

# Set build arguments
ARG VERSION

# Labels
LABEL \
    org.opencontainers.image.title="Coder (Custom)" \
    org.opencontainers.image.description="A custom build of Coder with license checking disabled" \
    org.opencontainers.image.url="https://github.com/coder/coder" \
    org.opencontainers.image.source="https://github.com/coder/coder" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.vendor="Custom Build" \
    custom.license.checking="disabled"

# Copy the binary from the Go builder stage
COPY --from=go-builder --chmod=0755 /opt/coder /opt/coder

# Expose the default Coder port
EXPOSE 3000

# Set the entrypoint
ENTRYPOINT ["/opt/coder", "server"]
