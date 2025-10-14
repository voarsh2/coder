#!/bin/bash

# Custom build script for Coder with license checking disabled
# This script builds both the Go binary and the Docker image

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
VERSION="${CODER_VERSION:-$(cd "$REPO_ROOT" && ./scripts/version.sh)}"
IMAGE_NAME="${CODER_IMAGE_NAME:-coder-custom}"
IMAGE_TAG="${CODER_IMAGE_TAG:-$VERSION}"
ARCH="${CODER_ARCH:-amd64}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Dependencies check passed"
}

# Build the Go binary
build_binary() {
    log_info "Building Go binary for $ARCH..."
    
    cd "$REPO_ROOT"
    
    # Set build environment variables
    export GOOS=linux
    export GOARCH="$ARCH"
    export CGO_ENABLED=0
    
    # Build the binary
    BINARY_PATH="$SCRIPT_DIR/coder_linux_$ARCH"
    if [ "$ARCH" = "amd64" ]; then
        BINARY_PATH="$SCRIPT_DIR/coder_linux_amd64"
    elif [ "$ARCH" = "arm64" ]; then
        BINARY_PATH="$SCRIPT_DIR/coder_linux_arm64"
    elif [ "$ARCH" = "armv7" ]; then
        BINARY_PATH="$SCRIPT_DIR/coder_linux_armv7"
        export GOARM=7
    fi
    
    log_info "Building binary at $BINARY_PATH..."
    
    go build \
        -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=$VERSION -s -w" \
        -o "$BINARY_PATH" \
        ./enterprise/cmd/coder
    
    if [ $? -eq 0 ]; then
        log_info "Go binary built successfully"
    else
        log_error "Failed to build Go binary"
        exit 1
    fi
}

# Build the Docker image
build_docker_image() {
    log_info "Building Docker image..."
    
    # Determine the binary path based on architecture
    BINARY_PATH=""
    if [ "$ARCH" = "amd64" ]; then
        BINARY_PATH="$SCRIPT_DIR/coder_linux_amd64"
    elif [ "$ARCH" = "arm64" ]; then
        BINARY_PATH="$SCRIPT_DIR/coder_linux_arm64"
    elif [ "$ARCH" = "armv7" ]; then
        BINARY_PATH="$SCRIPT_DIR/coder_linux_armv7"
    fi
    
    if [ ! -f "$BINARY_PATH" ]; then
        log_error "Binary not found at $BINARY_PATH. Please build the binary first."
        exit 1
    fi
    
    # Create a temporary directory for the Docker build context
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy the binary and Dockerfile to the temp directory
    cp "$BINARY_PATH" "$TEMP_DIR/coder"
    cp "$SCRIPT_DIR/Dockerfile" "$TEMP_DIR/"
    
    # Set Docker build arguments
    DOCKER_ARGS=(
        --build-arg "BASE_IMAGE=ghcr.io/coder/coder-base:latest"
        --build-arg "CODER_VERSION=$VERSION"
        --tag "$IMAGE_NAME:$IMAGE_TAG"
        --file "Dockerfile"
    )
    
    # Add platform if not amd64
    if [ "$ARCH" != "amd64" ]; then
        DOCKER_ARGS+=(--platform "linux/$ARCH")
    fi
    
    # Build the Docker image
    cd "$TEMP_DIR"
    docker build "${DOCKER_ARGS[@]}" .
    
    if [ $? -eq 0 ]; then
        log_info "Docker image built successfully: $IMAGE_NAME:$IMAGE_TAG"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Main function
main() {
    log_info "Starting custom Coder build process..."
    log_info "Version: $VERSION"
    log_info "Architecture: $ARCH"
    log_info "Image: $IMAGE_NAME:$IMAGE_TAG"
    
    check_dependencies
    build_binary
    build_docker_image
    
    log_info "Build process completed successfully!"
    log_info "You can now run your custom Coder image with:"
    log_info "docker run -p 3000:3000 $IMAGE_NAME:$IMAGE_TAG"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version VERSION      Set the version (default: from ./scripts/version.sh)"
            echo "  --image-name NAME       Set the image name (default: coder-custom)"
            echo "  --image-tag TAG         Set the image tag (default: same as version)"
            echo "  --arch ARCH              Set the architecture (default: amd64)"
            echo "  --help, -h               Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
