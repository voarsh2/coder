# Custom Makefile for Coder with license checking disabled
# This Makefile provides convenient targets for building and running the custom Coder image

.PHONY: help build build-all run clean

# Default target
.DEFAULT_GOAL := help

# Configuration
VERSION := $(shell cd .. && ./scripts/version.sh)
IMAGE_NAME := coder-custom
IMAGE_TAG := $(VERSION)
ARCH := amd64

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)Custom Coder Build with License Checking Disabled$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  Version: $(VERSION)"
	@echo "  Image Name: $(IMAGE_NAME)"
	@echo "  Image Tag: $(IMAGE_TAG)"
	@echo "  Architecture: $(ARCH)"

build: ## Build the Go binary and Docker image for the default architecture
	@echo "$(GREEN)Building Coder binary and Docker image...$(NC)"
	@chmod +x build.sh
	@./build.sh --version $(VERSION) --image-name $(IMAGE_NAME) --image-tag $(IMAGE_TAG) --arch $(ARCH)

build-all: ## Build Docker images for all supported architectures
	@echo "$(GREEN)Building Coder for all architectures...$(NC)"
	@chmod +x build.sh
	@./build.sh --version $(VERSION) --image-name $(IMAGE_NAME) --image-tag $(IMAGE_TAG) --arch amd64
	@./build.sh --version $(VERSION) --image-name $(IMAGE_NAME) --image-tag $(IMAGE_TAG)-arm64 --arch arm64
	@./build.sh --version $(VERSION) --image-name $(IMAGE_NAME) --image-tag $(IMAGE_TAG)-armv7 --arch armv7

run: ## Run the custom Coder image
	@echo "$(GREEN)Starting Coder...$(NC)"
	@docker run -d --name coder-custom -p 3000:3000 $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)Coder is running at http://localhost:3000$(NC)"

run-compose: ## Run Coder using Docker Compose
	@echo "$(GREEN)Starting Coder with Docker Compose...$(NC)"
	@docker compose -f docker-compose.yml up -d
	@echo "$(GREEN)Coder is running at http://localhost:3000$(NC)"

stop: ## Stop the running Coder container
	@echo "$(YELLOW)Stopping Coder...$(NC)"
	@docker stop coder-custom || true
	@docker rm coder-custom || true
	@echo "$(GREEN)Coder stopped$(NC)"

stop-compose: ## Stop Coder when running with Docker Compose
	@echo "$(YELLOW)Stopping Coder with Docker Compose...$(NC)"
	@docker compose -f docker-compose.yml down
	@echo "$(GREEN)Coder stopped$(NC)"

logs: ## Show Coder logs
	@docker logs -f coder-custom

logs-compose: ## Show Coder logs when running with Docker Compose
	@docker compose -f docker-compose.yml logs -f

clean: ## Remove built binaries and Docker images
	@echo "$(YELLOW)Cleaning up...$(NC)"
	@rm -f coder_linux_*
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG)-arm64 || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG)-armv7 || true
	@echo "$(GREEN)Cleanup complete$(NC)"

clean-all: ## Remove all Docker images and containers
	@echo "$(RED)Removing all Docker images and containers...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)Cleanup complete$(NC)"

dev: ## Build and run Coder for development
	@echo "$(GREEN)Building and running Coder for development...$(NC)"
	@$(MAKE) build
	@$(MAKE) run

dev-compose: ## Build and run Coder for development using Docker Compose
	@echo "$(GREEN)Building and running Coder for development using Docker Compose...$(NC)"
	@$(MAKE) build
	@$(MAKE) run-compose

push: ## Push the Docker image to a registry (requires DOCKER_REGISTRY)
	@if [ -z "$(DOCKER_REGISTRY)" ]; then \
		echo "$(RED)Error: DOCKER_REGISTRY environment variable not set$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Pushing image to $(DOCKER_REGISTRY)...$(NC)"
	@docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@docker push $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)Image pushed to $(DOCKER_REGISTRY)$(NC)"

pull: ## Pull the Docker image from a registry (requires DOCKER_REGISTRY)
	@if [ -z "$(DOCKER_REGISTRY)" ]; then \
		echo "$(RED)Error: DOCKER_REGISTRY environment variable not set$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Pulling image from $(DOCKER_REGISTRY)...$(NC)"
	@docker pull $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@docker tag $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)Image pulled from $(DOCKER_REGISTRY)$(NC)"

check: ## Check if all enterprise features are enabled
	@echo "$(GREEN)Checking if all enterprise features are enabled...$(NC)"
	@docker run --rm $(IMAGE_NAME):$(IMAGE_TAG) sh -c 'echo "Checking entitlements..." && /opt/coder version --entitlements || echo "Entitlements check not available in this version"'
	@echo "$(GREEN)To manually verify, start Coder and check the /api/v2/entitlements endpoint$(NC)"
