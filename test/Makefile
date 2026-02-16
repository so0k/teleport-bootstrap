REPO_ROOT := $(shell git rev-parse --show-toplevel)
WORKING_DIR := $(shell pwd)

all: init setup

init: ## init working directory by initialising packer plugins
	@(cd ${REPO_ROOT}/packer;packer init .)
.PHONY: init

setup: ## Set up required before tests
	@echo "Setting up local Teleport Cluster for TF Provider"
	@mkdir -p teleport/data
	teleport configure -o "$(WORKING_DIR)/teleport/config.yaml" --data-dir "$(WORKING_DIR)/teleport/data"
	teleport start -c ./teleport/config.yaml --bootstrap ./teleport/terraform.yaml >stdout.log 2>stderr.log &
	@sleep 5
	@cat stderr.log
	tctl -c ./teleport/config.yaml auth sign --format=file --user=terraform --out=./terraform/teleport-identity --ttl=10h
.PHONY: setup

teardown: ## Tear down after tests
	@echo "Cleaning up local Teleport Cluster"
	@-killall teleport
	@rm -rf teleport/data
	@rm -rf teleport/config.yaml
	@rm -rf terraform/teleport-identity
	@rm -rf stdout.log
	@rm -rf stderr.log
	@echo "Done"
.PHONY: teardown
