# Custom Coder Build with License Checking Disabled

This folder contains a custom Docker-based build path for Coder with license bypass changes.

## Files

- `Dockerfile`: A multi-stage Dockerfile that builds the frontend, compiles the server binary, and assembles the runtime image
- `docker-compose.yml`: Docker Compose configuration for building and running the custom image
- `README.md`: This file with documentation

## Prerequisites

- Docker with buildx support

## Usage

### Option 1: Using Docker Compose (Recommended)

The `docker-compose.yml` file is configured to build the frontend, compile the Go binary, and assemble the final Docker image using `custom/Dockerfile`.

```bash
cd custom
docker-compose up --build
```

This will:
1. Build the Go binary using the source code from the parent directory
2. Create a Docker image with the built binary
3. Start both Coder and a PostgreSQL database
4. Make Coder available at `http://localhost:3000`

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

When using `docker-compose up --build`, the following happens:

1. **Frontend Build**: Docker builds the site assets with Node.js and pnpm.
2. **Go Binary Build**: Docker compiles the embedded Coder binary and supporting agent binaries.
3. **Docker Image Build**: Docker assembles the final runtime image from `ghcr.io/coder/coder-base:latest`.
4. **Container Startup**: Docker Compose starts the containers.
   - Starts the PostgreSQL database
   - Starts Coder with the database connection
   - Exposes port 3000 for access

## License Modifications

This custom build includes the following modifications to disable license checking:

1. **Default Entitlements**: Modified `coderd/entitlements/entitlements.go` to set all features as entitled by default
2. **Feature Disablement**: Commented out the code in `enterprise/coderd/license/license.go` that disables non-entitled features
3. **Bypass Mode**: `CODER_LICENSE_BYPASS=true` enables the bypass-oriented entitlement path in the server

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
