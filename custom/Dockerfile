# Multi-stage Dockerfile for building Coder with license bypass changes.

FROM node:20-alpine AS frontend-builder

RUN corepack enable

WORKDIR /src/site

COPY site/package.json site/pnpm-lock.yaml site/.npmrc ./

RUN corepack pnpm install --frozen-lockfile

COPY site/ ./

RUN corepack pnpm build

FROM golang:1.25.7-alpine AS go-builder

RUN apk add --no-cache ca-certificates git openssl unzip wget

WORKDIR /src

ARG VERSION=2.29.10
ARG ARCH=amd64

ENV GOOS=linux
ENV GOARCH=$ARCH
ENV CGO_ENABLED=0

COPY go.mod go.sum ./

RUN go mod download

COPY . .

COPY --from=frontend-builder /src/site/out ./site/out

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
    download_version=$(echo "${VERSION}" | sed -E 's/^v//; s/-devel\\+.*//') && \
    wget -O "/tmp/coder-windows.zip" "https://github.com/coder/coder/releases/download/v${download_version}/coder_${download_version}_windows_amd64.zip" && \
    cd /tmp && \
    unzip -j "coder-windows.zip" "coder.exe" && \
    mv "coder.exe" "/src/site/out/bin/coder-windows-amd64.exe" && \
    cd /src/site/out/bin && \
    openssl dgst -r -sha1 coder-* | tee coder.sha1

RUN export TS_EXTRA_SMALL="ts_omit_aws,ts_omit_bird,ts_omit_tap,ts_omit_kube" && \
    go build -tags "embed,$TS_EXTRA_SMALL" -buildvcs=false \
        -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=${VERSION} -s -w" \
        -o /opt/coder \
        ./enterprise/cmd/coder && \
    chmod +x /opt/coder

FROM ghcr.io/coder/coder-base:latest

ARG VERSION=2.29.10

LABEL \
    org.opencontainers.image.title="Coder (Custom)" \
    org.opencontainers.image.description="A custom build of Coder with license bypass changes" \
    org.opencontainers.image.url="https://github.com/coder/coder" \
    org.opencontainers.image.source="https://github.com/coder/coder" \
    org.opencontainers.image.version="$VERSION" \
    org.opencontainers.image.vendor="Custom Build" \
    custom.license.checking="disabled"

COPY --from=go-builder --chmod=0755 /opt/coder /opt/coder

EXPOSE 3000

ENTRYPOINT ["/opt/coder", "server"]
