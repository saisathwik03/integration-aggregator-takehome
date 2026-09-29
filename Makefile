PYTHON := $(shell if [ -x .venv/bin/python ]; then echo .venv/bin/python; else echo python3; fi)

APP_RELEASE=integration-aggregator
APP_CHART=deploy/integration-aggregator
APP_IMAGE=integration-aggregator:local

OPENBAO_RELEASE=openbao
OPENBAO_NAMESPACE=openbao
OPENBAO_CHART=openbao/openbao
OPENBAO_VALUES=deploy/openbao/values.yaml

OPENBAO_TOKEN?=root


.PHONY: up down test build load deploy e2e

up:
	@echo "Starting Minikube..."
	minikube status || minikube start --driver=docker

	@echo "Adding OpenBao Helm repository..."
	helm repo add openbao https://openbao.github.io/openbao-helm || true
	helm repo update

	@echo "Installing OpenBao..."
	helm upgrade --install $(OPENBAO_RELEASE) \
		$(OPENBAO_CHART) \
		--namespace $(OPENBAO_NAMESPACE) \
		--create-namespace \
		--force-conflicts \
		-f $(OPENBAO_VALUES)

	@echo "Waiting for OpenBao..."
	kubectl wait \
		--namespace $(OPENBAO_NAMESPACE) \
		--for=condition=ready pod/openbao-0 \
		--timeout=180s

	@echo "Enabling OAuth2 secrets engine if needed..."
	kubectl exec -n $(OPENBAO_NAMESPACE) openbao-0 -- \
		sh -c 'bao secrets list -format=json | grep -q "\"oauth2/\"" || bao secrets enable -path=oauth2 oauthapp'

	@echo "Building application image..."
	docker build -t $(APP_IMAGE) .

	@echo "Loading image into Minikube..."
	minikube image load $(APP_IMAGE)

	@echo "Deploying application..."
	helm upgrade --install $(APP_RELEASE) \
		$(APP_CHART) \
		--set-string openbao.token="$(OPENBAO_TOKEN)"

	@echo "Waiting for application..."
	kubectl wait \
		--for=condition=available \
		deployment/$(APP_RELEASE)-integration-aggregator \
		--timeout=180s

	@echo "Application is ready."

down:
	@echo "Removing application..."
	helm uninstall $(APP_RELEASE) || true

	@echo "Removing OpenBao..."
	helm uninstall $(OPENBAO_RELEASE) \
		--namespace $(OPENBAO_NAMESPACE) || true

	@echo "Stopping Minikube..."
	minikube stop

test:
	$(PYTHON) -m pytest -q

build:
	docker build -t $(APP_IMAGE) .

load:
	minikube image load $(APP_IMAGE)

deploy:
	helm upgrade --install $(APP_RELEASE) \
		$(APP_CHART) \
		--set-string openbao.token="$(OPENBAO_TOKEN)"

e2e:
	./scripts/e2e.sh