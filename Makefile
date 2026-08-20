SHELL=/usr/bin/env bash -o pipefail

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

TOOLS_BIN_DIR ?= $(ROOT_DIR)/tmp/bin
export PATH := $(TOOLS_BIN_DIR):$(PATH)
MDTOC_BINARY=$(TOOLS_BIN_DIR)/mdtoc
MISSPELL_BINARY=$(TOOLS_BIN_DIR)/misspell

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN { FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\n"} /^[a-zA-Z0-9][a-zA-Z0-9_ -]*:.*##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: clean
clean: ## Remove all generated files and directories.
	rm -rf $(TOOLS_BIN_DIR)

##@ Generating

.PHONY: toc-update
toc-update: $(MDTOC_BINARY) ## Update table of contents in markdown files.
	@echo "Updating tables of contents..."
	find $(ROOT_DIR) -name '*.md' \
	    -not -path "*/tmp/*" \
	    -not -name "MAINTAINERS.md" \
	    -not -name "PULL_REQUEST_TEMPLATE.md" \
	    | xargs $(MDTOC_BINARY) --inplace --max-depth=5

.PHONY: spelling-update
spelling-update: $(MISSPELL_BINARY) ## Fix spelling errors in markdown files.
	@echo "Fixing spelling errors..."
	find $(ROOT_DIR) -name '*.md' \
	    -not -path "*/tmp/*" \
	    | xargs $(MISSPELL_BINARY) -w

##@ Checking

.PHONY: toc-verify
toc-verify: $(MDTOC_BINARY) ## Verify table of contents are up to date.
	@echo "Checking table of contents..."
	find $(ROOT_DIR) -name '*.md' \
	    -not -path "*/tmp/*" \
	    -not -name "MAINTAINERS.md" \
	    -not -name "PULL_REQUEST_TEMPLATE.md" \
	    | xargs $(MDTOC_BINARY) --inplace --max-depth=5 --dryrun || ( \
	      echo "Table of contents not up to date. Did you run 'make toc-update'?"; \
	      exit 1 \
	    )

.PHONY: spelling-verify
spelling-verify: $(MISSPELL_BINARY) ## Verify spelling in markdown files.
	@echo "Checking spelling..."
	find $(ROOT_DIR) -name '*.md' \
	    -not -path "*/tmp/*" \
	    | xargs $(MISSPELL_BINARY) -error || ( \
	      echo "Spelling errors found. Did you run 'make spelling-update'?"; \
	      exit 1 \
	    )

##@ Dependencies

.PHONY: tidy
tidy: ## Tidy Go module dependencies.
	@echo "Tidying scripts/go.mod..."
	cd $(ROOT_DIR)/scripts && go mod tidy -v

## Binaries

$(TOOLS_BIN_DIR):
	mkdir -p $(TOOLS_BIN_DIR)

$(MDTOC_BINARY) $(MISSPELL_BINARY): $(TOOLS_BIN_DIR)
	@echo "Installing tools from scripts/tools.go"
	@cd $(ROOT_DIR)/scripts && GOBIN=$(TOOLS_BIN_DIR) go install -mod=readonly -modfile=go.mod $$(cat tools.go | grep _ | awk -F'"' '{print $$2}')
