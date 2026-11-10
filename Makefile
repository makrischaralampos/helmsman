SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

CLUSTER   := helmsman
NAMESPACE := helmsman
RELEASE   := helmsman
COMMIT    := $(shell git rev-parse --short HEAD)
IMAGE     := helmsman:$(COMMIT)

.PHONY: help test lint image scan cluster load deploy smoke up clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

test: ## Run unit tests
	cd app && mvn -B verify

lint: ## Lint the chart and scan its manifests
	helm lint charts/helmsman
	trivy config --ignorefile .trivyignore.config --exit-code 1 charts/helmsman

image: ## Build the container image tagged with the git commit
	docker build -t $(IMAGE) --build-arg APP_VERSION=local --build-arg GIT_COMMIT=$(COMMIT) app

scan: ## Fail on fixable HIGH/CRITICAL vulnerabilities in the image
	trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 $(IMAGE)

cluster: ## Create the kind cluster if it does not exist
	@kind get clusters | grep -qx $(CLUSTER) || kind create cluster --config deploy/kind-config.yaml

load: ## Load the local image into the kind cluster
	kind load docker-image $(IMAGE) --name $(CLUSTER)

deploy: ## Deploy the chart into the restricted namespace
	kubectl apply -f deploy/namespace.yaml
	helm upgrade --install $(RELEASE) charts/helmsman \
		--namespace $(NAMESPACE) \
		--set image.repository=helmsman \
		--set image.tag=$(COMMIT) \
		--set image.pullPolicy=Never \
		--atomic --wait --timeout 120s

smoke: ## Run the smoke test against the deployment
	EXPECTED_COMMIT=$(COMMIT) NAMESPACE=$(NAMESPACE) RELEASE=$(RELEASE) ./scripts/smoke-test.sh

up: test lint image scan cluster load deploy smoke ## Run the whole pipeline locally

clean: ## Delete the kind cluster
	kind delete cluster --name $(CLUSTER)
