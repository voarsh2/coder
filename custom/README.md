# Custom Coder Build with License Checking Disabled

This folder contains a custom build system for Coder that includes all the necessary components to build a complete Docker image with license checking disabled.

## Files

- `build.sh`: A comprehensive build script that builds both the Go binary and the Docker image
- `Dockerfile`: A simple Dockerfile for use with pre-built binaries
- `Dockerfile.build`: A multi-stage Dockerfile that builds both the Go binary and the Docker image
- `docker-compose.yml`: Docker Compose configuration that builds the Go binary and Docker image
- `.env`: Environment variables for configuration
- `Makefile`: A Makefile with convenient targets for building and running
- `README.md`: This file with documentation

## Prerequisites

- Go 1.21 or later
- Docker with buildx support
- Make (optional, for using the official build system)

## Usage

### Option 1: Using Docker Compose (Recommended)

The `docker-compose.yml` file is configured to build both the Go binary and the Docker image from scratch using the `Dockerfile.build` file.

```bash
cd custom
docker-compose up --build
```

This will:
1. Build the Go binary using the source code from the parent directory
2. Create a Docker image with the built binary
3. Start both Coder and a PostgreSQL database
4. Make Coder available at `http://localhost:3000`

### Option 2: Using the Build Script

```bash
cd custom
chmod +x build.sh
./build.sh
docker run -p 3000:3000 coder-custom:latest
```

### Option 3: Using the Makefile

```bash
cd custom
make build-compose
make run-compose
```

## Configuration

You can customize the build by modifying the `.env` file or by passing environment variables:

```bash
# Build for a different architecture
ARCH=arm64 docker-compose up --build

# Use a custom version
VERSION=v2.0.0 docker-compose up --build

# Override multiple settings
docker-compose --env-file .env.custom up --build
```

## Build Process

### Docker Compose Build Process

When using `docker-compose up --build`, the following happens:

1. **Go Binary Build**: Docker builds the Go binary using the `Dockerfile.build` file
   - Uses a Go 1.21 Alpine image as the builder
   - Downloads dependencies
   - Builds the binary with your license modifications
   - Outputs the binary to `/opt/coder`

2. **Docker Image Build**: Docker creates the final image
   - Uses the official Coder base image
   - Copies the binary from the builder stage
   - Sets up proper permissions and user
   - Configures the entrypoint

3. **Container Startup**: Docker Compose starts the containers
   - Starts the PostgreSQL database
   - Starts Coder with the database connection
   - Exposes port 3000 for access

### Standalone Build Script Process

The `build.sh` script follows a similar process but builds the binary on the host machine:

1. **Go Binary Build**: Builds the Go binary using the host's Go toolchain
2. **Docker Image Build**: Builds a Docker image using the pre-built binary

## License Modifications

This custom build includes the following modifications to disable license checking:

1. **Default Entitlements**: Modified `coderd/entitlements/entitlements.go` to set all features as entitled by default
2. **Feature Disablement**: Commented out the code in `enterprise/coderd/license/license.go` that disables non-entitled features
3. **Managed Agent Limit**: Bypassed the managed agent limit check in `enterprise/coderd/coderd.go`

## Verification

To verify that the license checking has been disabled:

1. Start Coder using one of the methods above
2. Access the Coder UI at `http://localhost:3000`
3. Check the `/api/v2/entitlements` endpoint or look for enterprise features in the UI

All enterprise features should be enabled without requiring a license.

## Troubleshooting

### Build Fails with "Go not found"
When using Docker Compose, this shouldn't happen as Go is installed in the builder container. For the standalone build script, make sure Go is installed and in your PATH.

### Docker Build Fails with "platform not supported"
Make sure you have Docker buildx installed and configured for multi-platform builds:
```bash
docker buildx version
```

### Database Connection Errors
Make sure the PostgreSQL container is running and accessible:
```bash
docker-compose logs postgres
```

## Integration with CI/CD

This custom build system can be easily integrated into CI/CD pipelines:

### GitHub Actions Example

```yaml
name: Build Custom Coder

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Build Custom Coder
      run: |
        cd custom
        docker-compose build
    
    - name: Push to Registry
      if: github.ref == 'refs/heads/main'
      run: |
        docker push my-coder:${{ github.sha }}
```

## Security Considerations

This custom build disables license checking, which means all enterprise features are enabled without validation. Consider the following security implications:

1. **Feature Access**: All users will have access to enterprise features
2. **Compliance**: This build may not comply with Coder's licensing terms
3. **Support**: This build is not officially supported by Coder

Use this custom build only in environments where you have the authority to disable license checking.

# Docker Run
docker run -d --name coder-debug -p 3000:3000 -e CODER_HTTP_ADDRESS=0.0.0.0:3000 -e CODER_ACCESS_URL=http://localhost:3000 -e CODER_TELEMETRY_ENABLE=false -e CODER_TUNNEL=false coder-custom:latest