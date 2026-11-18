
# ==========================================
# AI Inference Stack
# vLLM + LiteLLM + Qwen + Tailscale
# ==========================================

.DEFAULT_GOAL := help

SHELL := /bin/bash

COMPOSE := docker compose
PROJECT_DIR := $(CURDIR)

.PHONY: help setup check-gpu config pull build \
        up down start stop restart status ps \
        logs logs-vllm logs-litellm \
        test test-local models health \
        gpu gpu-live \
        remote-up remote-down remote-status \
        update clean reset

# ------------------------------------------
# Help
# ------------------------------------------

help:
	@echo ""
	@echo "========================================"
	@echo " AI Inference Stack"
	@echo " vLLM + LiteLLM + Qwen + Tailscale"
	@echo "========================================"
	@echo ""
	@echo "SETUP:"
	@echo "  make setup           Prepare environment"
	@echo "  make check-gpu       Check NVIDIA GPU"
	@echo "  make config          Validate Docker Compose"
	@echo "  make pull            Download Docker images"
	@echo ""
	@echo "SERVICES:"
	@echo "  make up              Start all services"
	@echo "  make down            Stop and remove containers"
	@echo "  make start           Start existing containers"
	@echo "  make stop            Stop containers"
	@echo "  make restart         Restart containers"
	@echo "  make status          Show service status"
	@echo ""
	@echo "LOGS:"
	@echo "  make logs            Show all logs"
	@echo "  make logs-vllm       Show vLLM logs"
	@echo "  make logs-litellm    Show LiteLLM logs"
	@echo ""
	@echo "TESTING:"
	@echo "  make test            Test Qwen API"
	@echo "  make models          List available models"
	@echo "  make health          Check LiteLLM health"
	@echo ""
	@echo "GPU:"
	@echo "  make gpu             GPU status"
	@echo "  make gpu-live        Live GPU monitoring"
	@echo ""
	@echo "REMOTE ACCESS:"
	@echo "  make remote-up       Enable Tailscale HTTPS"
	@echo "  make remote-down     Disable Tailscale Serve"
	@echo "  make remote-status   Show remote access URL"
	@echo ""
	@echo "MAINTENANCE:"
	@echo "  make update          Update images and restart"
	@echo "  make clean           Remove containers"
	@echo "  make reset           Remove containers AND volumes"
	@echo ""

# ------------------------------------------
# Initial Setup
# ------------------------------------------

setup:
	@echo "Preparing inference stack..."
	@command -v docker >/dev/null || \
		(echo "Docker is not installed" && exit 1)
	@docker compose version >/dev/null || \
		(echo "Docker Compose is not available" && exit 1)
	@command -v nvidia-smi >/dev/null || \
		(echo "NVIDIA driver tools are not available" && exit 1)
	@command -v openssl >/dev/null || \
		(echo "OpenSSL is required" && exit 1)
	@if [ ! -f .env ]; then \
		printf 'LITELLM_MASTER_KEY=sk-%s\n' \
		"$$(openssl rand -hex 32)" > .env; \
		echo "Created .env with a random API key"; \
	else \
		echo ".env already exists; preserving it"; \
	fi
	@chmod 600 .env
	@chmod +x test-local.sh enable-private-access.sh
	@$(COMPOSE) config --quiet
	@echo "Setup completed."

# ------------------------------------------
# GPU
# ------------------------------------------

check-gpu:
	@nvidia-smi
	@echo "Checking Docker GPU access..."
	@docker run --rm --gpus all \
		nvidia/cuda:12.8.0-base-ubuntu24.04 \
		nvidia-smi

gpu:
	@nvidia-smi

gpu-live:
	@watch -n 1 nvidia-smi

# ------------------------------------------
# Docker Configuration
# ------------------------------------------

config:
	@$(COMPOSE) config --quiet
	@echo "Docker Compose configuration is valid."

pull:
	@$(COMPOSE) pull

build:
	@$(COMPOSE) build

# ------------------------------------------
# Service Management
# ------------------------------------------

up:
	@echo "Starting vLLM and LiteLLM..."
	@$(COMPOSE) up -d
	@$(COMPOSE) ps

down:
	@$(COMPOSE) down

start:
	@$(COMPOSE) start

stop:
	@$(COMPOSE) stop

restart:
	@$(COMPOSE) restart

status ps:
	@$(COMPOSE) ps

# ------------------------------------------
# Logs
# ------------------------------------------

logs:
	@$(COMPOSE) logs -f --tail=100

logs-vllm:
	@$(COMPOSE) logs -f --tail=100 vllm

logs-litellm:
	@$(COMPOSE) logs -f --tail=100 litellm

# ------------------------------------------
# API Testing
# ------------------------------------------

test test-local:
	@bash ./test-local.sh

models:
	@set -a; source .env; set +a; \
	curl --fail-with-body -sS \
		http://127.0.0.1:4000/v1/models \
		-H "Authorization: Bearer $$LITELLM_MASTER_KEY"; \
	echo ""

health:
	@curl --fail-with-body -sS \
		http://127.0.0.1:4000/health/liveliness
	@echo ""

# ------------------------------------------
# Remote Access (Tailscale)
# ------------------------------------------

remote-up:
	@bash ./enable-private-access.sh

remote-down:
	@sudo tailscale serve off
	@echo "Tailscale remote access disabled."

remote-status:
	@tailscale serve status

# ------------------------------------------
# Maintenance
# ------------------------------------------

update:
	@$(COMPOSE) pull
	@$(COMPOSE) up -d
	@echo "Stack updated."

clean:
	@$(COMPOSE) down --remove-orphans
	@echo "Containers removed; volumes preserved."

# WARNING: Deletes persistent model caches.
reset:
	@echo "WARNING: This removes all Compose volumes,"
	@echo "including downloaded model caches."
	@read -r -p "Type RESET to continue: " answer; \
	if [ "$$answer" = "RESET" ]; then \
		$(COMPOSE) down -v --remove-orphans; \
	else \
		echo "Cancelled."; \
	fi
