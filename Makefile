SHELL := /bin/bash

PREFIX ?= p4-es
RELEASE-MASTER ?= $(PREFIX)-master
RELEASE-DATA ?= $(PREFIX)-data
RELEASE-CLIENT ?= $(PREFIX)-client
NAMESPACE ?= elastic
TIMEOUT := 1200s

CHART_NAME ?= elastic/elasticsearch
CHART_VERSION ?= 7.17.1

DEV_CLUSTER ?= p4-development
DEV_PROJECT ?= planet-4-151612
DEV_ZONE ?= us-central1-a

PROD_CLUSTER ?= planet4-production
PROD_PROJECT ?= planet4-production
PROD_ZONE ?= us-central1-a

.DEFAULT_GOAL := status

# ---------------------------
# Linting & Formatting
# ---------------------------
lint: lint-yaml lint-ci

lint-yaml:
	@find . -type f -name '*.yml' | xargs yamllint
	@find . -type f -name '*.yaml' | xargs yamllint

lint-ci:
	@circleci config validate

fmt:
	@echo "🔧 Auto-formatting YAML files..."
	# Remove trailing spaces
	@find . -type f \( -name '*.yml' -o -name '*.yaml' \) -exec sed -i 's/[ \t]*$$//' {} +
	# Ensure newline at end of file
	@find . -type f \( -name '*.yml' -o -name '*.yaml' \) -exec sh -c 'tail -c1 "$$1" | read -r _ || echo >> "$$1"' sh {} \;
	@echo "✅ YAML formatting done"

install-hooks:
	@echo "🔗 Installing pre-commit Git hook..."
	@mkdir -p .git/hooks
	@echo '#!/bin/bash' > .git/hooks/pre-commit
	@echo 'echo "🔎 Running make fmt before commit..."' >> .git/hooks/pre-commit
	@echo 'make fmt' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Pre-commit hook installed. YAML will be auto-formatted on each commit."

# ---------------------------
# Helm Initialisation
# ---------------------------
init:
	helm repo add elastic https://helm.elastic.co
	helm repo update

# ---------------------------
# Development Deployment
# ---------------------------
dev:
	gcloud config set project $(DEV_PROJECT)
	gcloud container clusters get-credentials $(DEV_CLUSTER) --zone $(DEV_ZONE) --project $(DEV_PROJECT)
	-kubectl create namespace $(NAMESPACE)

	helm upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-MASTER) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-master.yaml \
		--values env/dev/values-master.yaml \
		$(CHART_NAME)
	helm history $(RELEASE-MASTER) -n $(NAMESPACE) --max=5

	helm upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-DATA) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-data.yaml \
		--values env/dev/values-data.yaml \
		$(CHART_NAME)
	helm history $(RELEASE-DATA) -n $(NAMESPACE) --max=5

	helm upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-CLIENT) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-client.yaml \
		--values env/dev/values-client.yaml \
		$(CHART_NAME)
	helm history $(RELEASE-CLIENT) -n $(NAMESPACE) --max=5	

# ---------------------------
# Production Deployment
# ---------------------------
prod: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(PROD_PROJECT)
	gcloud container clusters get-credentials $(PROD_CLUSTER) --zone $(PROD_ZONE) --project $(PROD_PROJECT)
	-kubectl create namespace $(NAMESPACE)

	helm upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-MASTER) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-master.yaml \
		--values env/prod/values-master.yaml \
		$(CHART_NAME)
	helm history $(RELEASE-MASTER) -n $(NAMESPACE) --max=5

	helm upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-DATA) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-data.yaml \
		--values env/prod/values-data.yaml \
		$(CHART_NAME)
	helm history $(RELEASE-DATA) -n $(NAMESPACE) --max=5

	helm upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-CLIENT) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-client.yaml \
		--values env/prod/values-client.yaml \
		$(CHART_NAME)
	helm history $(RELEASE-CLIENT) -n $(NAMESPACE) --max=5	

# ---------------------------
# Utilities
# ---------------------------
port:
	@echo "Visit http://127.0.0.1:9200 to use Elasticsearch"
	kubectl port-forward --namespace $(NAMESPACE) \
		$$(kubectl get pod --namespace $(NAMESPACE) \
		--selector="app=elasticsearch-client,chart=elasticsearch,release=$(RELEASE-CLIENT)" \
		--output jsonpath='{.items[0].metadata.name}') 9200:9200

status:
	helm status $(RELEASE-MASTER) -n $(NAMESPACE)
	helm status $(RELEASE-DATA) -n $(NAMESPACE)
	helm status $(RELEASE-CLIENT) -n $(NAMESPACE)

values:
	helm get values $(RELEASE-MASTER) -n $(NAMESPACE)
	helm get values $(RELEASE-DATA) -n $(NAMESPACE)
	helm get values $(RELEASE-CLIENT) -n $(NAMESPACE)

history:
	helm history $(RELEASE-MASTER) -n $(NAMESPACE) --max=5
	helm history $(RELEASE-DATA) -n $(NAMESPACE) --max=5
	helm history $(RELEASE-CLIENT) -n $(NAMESPACE) --max=5

uninstall:
	helm uninstall $(RELEASE-MASTER) -n $(NAMESPACE) --keep-history
	helm uninstall $(RELEASE-DATA) -n $(NAMESPACE) --keep-history
	helm uninstall $(RELEASE-CLIENT) -n $(NAMESPACE) --keep-history

destroy:
	@echo -n "You are about to ** DELETE DATA **, enter y if your sure ? [y/N] " && read ans && [ $${ans:-N} = y ]
	helm uninstall $(RELEASE-MASTER) -n $(NAMESPACE)
	helm uninstall $(RELEASE-DATA) -n $(NAMESPACE)
	helm uninstall $(RELEASE-CLIENT) -n $(NAMESPACE)
	kubectl delete pvc -l release=$(RELEASE-MASTER),component=data -n $(NAMESPACE) || true
	kubectl delete pvc -l release=$(RELEASE-DATA),component=data -n $(NAMESPACE) || true
	kubectl delete pvc -l release=$(RELEASE-MASTER),component=master -n $(NAMESPACE) || true
	kubectl delete pvc -l release=$(RELEASE-DATA),component=master -n $(NAMESPACE) || true
	kubectl delete statefulset $(RELEASE-DATA)-es-elasticsearch-data -n $(NAMESPACE) || true
