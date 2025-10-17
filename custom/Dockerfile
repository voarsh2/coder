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

# Build a helper binary to get the version
RUN go build -o /opt/get-version -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=${VERSION}" ./cmd/coder/version 2>/dev/null || \
    echo "package main; import \"fmt\"; import \"github.com/coder/coder/v2/buildinfo\"; func main() { fmt.Print(buildinfo.Version()) }" > /tmp/get-version.go && \
    go build -o /opt/get-version -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=${VERSION}" /tmp/get-version.go

# Download official agent binaries (default approach)
# RUN mkdir -p /src/site/out/bin && \
#     BINARY_VERSION=$(/opt/get-version) && \
#     DOWNLOAD_VERSION=$(echo "${BINARY_VERSION}" | sed 's/-devel+.*//') && \
#     echo "Binary version: ${BINARY_VERSION}" && \
#     echo "Download version: ${DOWNLOAD_VERSION}" && \
#     wget -O "/src/site/out/bin/coder-linux-amd64" "https://github.com/coder/coder/releases/download/${DOWNLOAD_VERSION}/coder-linux-amd64" && \
#     wget -O "/src/site/out/bin/coder-linux-arm64" "https://github.com/coder/coder/releases/download/${DOWNLOAD_VERSION}/coder-linux-arm64" && \
#     wget -O "/src/site/out/bin/coder-linux-armv7" "https://github.com/coder/coder/releases/download/${DOWNLOAD_VERSION}/coder-linux-armv7" && \
#     cd /src/site/out/bin && \
#     openssl dgst -r -sha1 coder-linux-* | tee coder.sha1

# Alternative: Build agent binaries from source (uncomment to use)
RUN mkdir -p /src/site/out/bin && \
    for arch in amd64 arm64 armv7; do \
        export GOOS=linux GOARCH=$arch CGO_ENABLED=0; \
        if [ "$arch" = "armv7" ]; then export GOARM=7; fi; \
        go build -tags "embed" \
            -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=${VERSION} -s -w" \
            -o "/src/site/out/bin/coder-linux-$arch" \
            ./enterprise/cmd/coder; \
    done && \
    cd /src/site/out/bin && \
    openssl dgst -r -sha1 coder-linux-* | tee coder.sha1

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
