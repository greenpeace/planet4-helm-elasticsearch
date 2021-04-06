SHELL := /bin/bash

PREFIX ?= p4-es
RELEASE-MASTER ?= $(PREFIX)-master
RELEASE-DATA ?= $(PREFIX)-data
RELEASE-CLIENT ?= $(PREFIX)-client
NAMESPACE	?= elastic
TIMEOUT := 1200s

CHART_NAME ?= elastic/elasticsearch
CHART_VERSION ?= 7.9.3

DEV_CLUSTER ?= p4-development
DEV_PROJECT ?= planet-4-151612
DEV_ZONE ?= us-central1-a

PROD_CLUSTER ?= planet4-production
PROD_PROJECT ?= planet4-production
PROD_ZONE ?= us-central1-a

.DEFAULT_TARGET := status

.DEFAULT_TARGET: status

lint: lint-yaml lint-ci

lint-yaml:
		@find . -type f -name '*.yml' | xargs yamllint
		@find . -type f -name '*.yaml' | xargs yamllint

lint-ci:
		@circleci config validate

# Helm Initialisation
init:
	helm3 repo add elastic https://helm.elastic.co
	helm3 repo update

dev: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(DEV_PROJECT)
	gcloud container clusters get-credentials $(DEV_CLUSTER) --zone $(DEV_ZONE) --project $(DEV_PROJECT)
	-kubectl create namespace $(NAMESPACE)
	helm3 upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-MASTER) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-master.yaml \
		--values env/dev/values-master.yaml \
		$(CHART_NAME)
	helm3 history $(RELEASE-MASTER) -n $(NAMESPACE) --max=5
	helm3 upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-DATA) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-data.yaml \
		--values env/dev/values-data.yaml \
		$(CHART_NAME)
	helm3 history $(RELEASE-DATA) -n $(NAMESPACE) --max=5
	helm3 upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-CLIENT) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-client.yaml \
		--values env/dev/values-client.yaml \
		$(CHART_NAME)
	helm3 history $(RELEASE-CLIENT) -n $(NAMESPACE) --max=5	

prod: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(PROD_PROJECT)
	gcloud container clusters get-credentials $(PROD_PROJECT) --zone $(PROD_ZONE) --project $(PROD_PROJECT)
	-kubectl create namespace $(NAMESPACE)
	helm3 upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-MASTER) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-master.yaml \
		--values env/prod/values.yaml \
		$(CHART_NAME)
	helm3 history $(RELEASE-MASTER) -n $(NAMESPACE) --max=5
	helm3 upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-DATA) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-data.yaml \
		--values env/prod/values.yaml \
		$(CHART_NAME)
	helm3 history $(RELEASE-DATA) -n $(NAMESPACE) --max=5
	helm3 upgrade --install --timeout=$(TIMEOUT) --wait $(RELEASE-CLIENT) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		--values values.yaml \
		--values values-client.yaml \
		--values env/prod/values.yaml \
		$(CHART_NAME)
	helm3 history $(RELEASE-CLIENT) -n $(NAMESPACE) --max=5	
port:
	@echo "Visit http://127.0.0.1:9200 to use Elasticsearch"
	kubectl port-forward --namespace $(NAMESPACE) $(shell kubectl get service --namespace $(NAMESPACE) -l "app=elasticsearch,component=client,release=$(RELEASE)" -o name) 9200:9200

# Helm status
status:
	helm3 status $(RELEASE-MASTER) -n $(NAMESPACE)
	helm3 status $(RELEASE-DATA) -n $(NAMESPACE)
	helm3 status $(RELEASE-CLIENT) -n $(NAMESPACE)

# Display user values
values:
	helm3 get values $(RELEASE-MASTER) -n $(NAMESPACE)
	helm3 get values $(RELEASE-DATA) -n $(NAMESPACE)
	helm3 get values $(RELEASE-CLIENT) -n $(NAMESPACE)

# Display helm history
history:
	helm3 history $(RELEASE-MASTER) -n $(NAMESPACE) --max=5
	helm3 history $(RELEASE-DATA) -n $(NAMESPACE) --max=5
	helm3 history $(RELEASE-CLIENT) -n $(NAMESPACE) --max=5

# Delete a release when you intend reinstalling it to keep history
uninstall:
	helm3 uninstall $(RELEASE-MASTER) -n $(NAMESPACE) --keep-history
	helm3 uninstall $(RELEASE-DATA) -n $(NAMESPACE) --keep-history
	helm3 uninstall $(RELEASE-CLIENT) -n $(NAMESPACE) --keep-history

# Completely remove helm install, config data, persistent volumes etc.
# Before running this ensure you have deleted any other related config
destroy:
	@echo -n "You are about to ** DELETE DATA **, enter y if your sure ? [y/N] " && read ans && [ $${ans:-N} = y ]
	helm3 uninstall $(RELEASE-MASTER) -n $(NAMESPACE)
	helm3 uninstall $(RELEASE-DATA) -n $(NAMESPACE)
	helm3 uninstall $(RELEASE-CLIENT) -n $(NAMESPACE)
	kubectl delete pvc -l release=$(RELEASE),component=data -n $(NAMESPACE)
	kubectl delete pvc -l release=$(RELEASE),component=master -n $(NAMESPACE)
	kubectl delete statefulset $(RELEASE)-es-elasticsearch-data -n $(NAMESPACE)
