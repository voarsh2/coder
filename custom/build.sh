#!/bin/bash

# Custom build script for Coder with license checking disabled
# This script installs dependencies and builds both the Go binary and the Docker image

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
VERSION="${CODER_VERSION:-$(cd "$REPO_ROOT" && ./scripts/version.sh)}"
IMAGE_NAME="${CODER_IMAGE_NAME:-coder-custom}"
# Sanitize version to create a valid Docker tag
IMAGE_TAG="${CODER_IMAGE_TAG:-$VERSION}"
IMAGE_TAG=$(echo "$IMAGE_TAG" | sed 's/[^a-zA-Z0-9._-]/_/g')
ARCH="${CODER_ARCH:-amd64}"
INSTALL_DEPS="${CODER_INSTALL_DEPS:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# OS detection
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

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

# Install dependencies based on OS
install_dependencies() {
    if [ "$INSTALL_DEPS" != "true" ]; then
        log_info "Skipping dependency installation (INSTALL_DEPS=false)"
        return
    fi
    
    log_info "Installing dependencies for $OS..."
    
    case "$OS" in
        linux)
            install_linux_deps
            ;;
        darwin)
            install_macos_deps
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    log_info "Dependencies installation completed"
}

# Install dependencies on Linux
install_linux_deps() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_warn "Not running as root, some dependencies might fail to install"
        SUDO="sudo"
    else
        SUDO=""
    fi
    
    # Update package list
    log_info "Updating package list..."
    $SUDO apt-get update || true
    
    # Install basic dependencies
    log_info "Installing basic dependencies..."
    $SUDO apt-get install -y curl wget git build-essential nodejs npm || true
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        $SUDO apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release || true
        $SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || true
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null || true
        $SUDO apt-get update || true
        $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io || true
        $SUDO systemctl start docker || true
        $SUDO systemctl enable docker || true
        $SUDO usermod -aG docker $USER || true
        log_warn "Docker installed, you may need to log out and log back in to use docker without sudo"
    fi
    
    # Install Go if not present
    if ! command -v go &> /dev/null; then
        log_info "Installing Go..."
        GO_VERSION="1.25.7"
        cd /tmp
        wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" || true
        $SUDO rm -rf /usr/local/go || true
        $SUDO tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" || true
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc || true
        export PATH=$PATH:/usr/local/go/bin
        cd "$SCRIPT_DIR"
        log_info "Go installed, you may need to run 'source ~/.bashrc' to use go"
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose..."
        $SUDO curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || true
        $SUDO chmod +x /usr/local/bin/docker-compose || true
    fi
}

# Install dependencies on macOS
install_macos_deps() {
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
        eval "$(/opt/homebrew/bin/brew shellenv)" || true
    fi
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker Desktop..."
        brew install --cask docker || true
        log_warn "Docker Desktop installed, please start it manually"
    fi
    
    # Install Go if not present
    if ! command -v go &> /dev/null; then
        log_info "Installing Go..."
        brew install go || true
    fi
    
    # Install Node.js if not present
    if ! command -v node &> /dev/null; then
        log_info "Installing Node.js..."
        brew install node || true
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose..."
        brew install docker-compose || true
    fi
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
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed or not in PATH"
        exit 1
    fi
    
    log_info "Dependencies check passed"
}

# Build the Go binary with frontend
build_binary() {
    log_info "Building Go binary for $ARCH with frontend..."
    
    cd "$REPO_ROOT"
    
    # Build the frontend first
    log_info "Building frontend..."
    cd site
    # Install pnpm if not present
    if ! command -v pnpm &> /dev/null; then
        log_info "Installing pnpm..."
        npm install -g pnpm
    fi
    pnpm install --frozen-lockfile
    pnpm build
    cd ..

    # Build agent binaries BEFORE building the main Go binary so they can be embedded
    build_agent_binaries

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

    go build -tags "embed" -buildvcs=false \
        -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=$VERSION -s -w" \
        -o "$BINARY_PATH" \
        ./enterprise/cmd/coder

    if [ $? -eq 0 ]; then
        log_info "Go binary with frontend and agent binaries built successfully"
    else
        log_error "Failed to build Go binary with frontend"
        exit 1
    fi
}

# Build agent binaries for all architectures
build_agent_binaries() {
    log_info "Building agent binaries for all architectures..."

    cd "$REPO_ROOT"

    # Create the output directory
    mkdir -p site/out/bin

    # Build binaries for all architectures (matching Dockerfile approach)
    for arch in amd64 arm64 arm; do
        log_info "Building agent binary for linux/$arch..."

        # Set architecture-specific variables
        export GOOS=linux
        export GOARCH=$arch
        export CGO_ENABLED=0

        # Set GOARM for arm architecture
        if [ "$arch" = "arm" ]; then
            export GOARM=7
        fi

        go build -tags "embed" -buildvcs=false \
            -ldflags "-X github.com/coder/coder/v2/buildinfo.tag=$VERSION -s -w" \
            -o "site/out/bin/coder-linux-$arch" \
            ./enterprise/cmd/coder
    done

    # Rename arm to armv7 to match expected naming
    if [ -f "site/out/bin/coder-linux-arm" ]; then
        mv "site/out/bin/coder-linux-arm" "site/out/bin/coder-linux-armv7"
    fi

    # Generate SHA1 hashes
    log_info "Generating SHA1 hashes..."
    cd site/out/bin
    openssl dgst -r -sha1 coder-linux-* | tee coder.sha1
    cd "$REPO_ROOT"

    log_info "Agent binaries built successfully"
}

# Build the Docker image using the built binary
build_docker_image() {
    log_info "Building Docker image with embedded frontend..."
    
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

# Build the Docker image using Docker Compose (build everything in Docker)
build_docker_compose() {
    log_info "Building Docker image using Docker Compose with frontend..."
    
    cd "$SCRIPT_DIR"
    
    # Set environment variables for Docker Compose
    export VERSION="$VERSION"
    export ARCH="$ARCH"
    export IMAGE_NAME="$IMAGE_NAME"
    export IMAGE_TAG="$IMAGE_TAG"
    
    # Build using Docker Compose
    if docker compose version &> /dev/null; then
        docker compose build
    else
        docker-compose build
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Docker image with frontend built successfully using Docker Compose: $IMAGE_NAME:$IMAGE_TAG"
    else
        log_error "Failed to build Docker image using Docker Compose"
        exit 1
    fi
}

# Main function
main() {
    log_info "Starting custom Coder build process with frontend..."
    log_info "Version: $VERSION"
    log_info "Architecture: $ARCH"
    log_info "Image: $IMAGE_NAME:$IMAGE_TAG"
    
    # Install dependencies if requested
    if [ "$INSTALL_DEPS" = "true" ]; then
        install_dependencies
    fi
    
    # Check dependencies
    check_dependencies
    
    # Build based on the method specified
    if [ "${BUILD_METHOD:-binary}" = "compose" ]; then
        build_docker_compose
    else
        build_binary
        build_docker_image
    fi
    
    log_info "Build process completed successfully!"
    log_info "You can now run your custom Coder image with:"
    log_info "docker run -p 3000:3000 -e CODER_ACCESS_URL=http://localhost:3000 $IMAGE_NAME:$IMAGE_TAG"
}

# Parse command line arguments
BUILD_METHOD="binary"
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
        --method)
            BUILD_METHOD="$2"
            shift 2
            ;;
        --no-install-deps)
            INSTALL_DEPS="false"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version VERSION      Set the version (default: from ./scripts/version.sh)"
            echo "  --image-name NAME       Set the image name (default: coder-custom)"
            echo "  --image-tag TAG         Set the image tag (default: same as version)"
            echo "  --arch ARCH              Set the architecture (default: amd64)"
            echo "  --method METHOD          Set the build method (binary|compose, default: binary)"
            echo "  --no-install-deps        Skip dependency installation"
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
