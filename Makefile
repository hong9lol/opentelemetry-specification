# All documents to be used in spell check.
ALL_DOCS := $(shell find . -name '*.md' -not -path './.github/*' -type f | grep -v ^./node_modules | sort)
PWD := $(shell pwd)

TOOLS_DIR := ./internal/tools
MISSPELL_BINARY=bin/misspell
MISSPELL = $(TOOLS_DIR)/$(MISSPELL_BINARY)
MARKDOWN_LINK_CHECK=./node_modules/.bin/markdown-link-check
MARKDOWN_LINT=./node_modules/.bin/markdownlint
MARKDOWN_TOC=./node_modules/.bin/markdown-toc

# see https://github.com/open-telemetry/build-tools/releases for semconvgen updates
# Keep links in semantic_conventions/README.md and .vscode/settings.json in sync!
SEMCONVGEN_VERSION=0.8.0

$(MISSPELL):
	cd $(TOOLS_DIR) && go build -o $(MISSPELL_BINARY) github.com/client9/misspell/cmd/misspell

.PHONY: misspell
misspell:	$(MISSPELL)
	$(MISSPELL) -error $(ALL_DOCS)

.PHONY: misspell-correction
misspell-correction:	$(MISSPELL)
	$(MISSPELL) -w $(ALL_DOCS)

$(MARKDOWN_LINK_CHECK):
	npm install markdown-link-check

.PHONY: markdown-link-check
markdown-link-check:	$(MARKDOWN_LINK_CHECK)
	@for f in $(ALL_DOCS); do $(MARKDOWN_LINK_CHECK) --quiet --config .markdown_link_check_config.json $$f; done

$(MARKDOWN_TOC):
	npm install markdown-toc

# This target runs markdown-toc on all files that contain
# a comment <!-- tocstop -->.
#
# The recommended way to prepate a .md file for markdown-toc is
# to add these comments:
#
#   <!-- toc -->
#   <!-- tocstop -->
.PHONY: markdown-toc
markdown-toc:	$(MARKDOWN_TOC)
	@for f in $(ALL_DOCS); do \
		if grep -q '<!-- tocstop -->' $$f; then \
			echo markdown-toc: processing $$f; \
			$(MARKDOWN_TOC) --no-first-h1 -i $$f; \
		else \
			echo markdown-toc: no TOC markers, skipping $$f; \
		fi; \
	done

$(MARKDOWN_LINT):
	npm install markdownlint-cli

.PHONY: markdownlint
markdownlint:	$(MARKDOWN_LINT)
	@for f in $(ALL_DOCS); do echo $$f; $(MARKDOWN_LINT) -c .markdownlint.yaml $$f || exit 1;	done

.PHONY: install-yamllint
install-yamllint:
    # Using a venv is recommended
	pip install -U yamllint~=1.26.1

.PHONY: yamllint
yamllint:
	yamllint .

# Generate markdown tables from YAML definitions
.PHONY: table-generation
table-generation:
	docker run --rm -v $(PWD)/semantic_conventions:/source -v $(PWD)/specification:/spec \
		otel/semconvgen:$(SEMCONVGEN_VERSION) -f /source markdown -md /spec

# Check if current markdown tables differ from the ones that would be generated from YAML definitions
.PHONY: table-check
table-check:
	docker run --rm -v $(PWD)/semantic_conventions:/source -v $(PWD)/specification:/spec \
		otel/semconvgen:$(SEMCONVGEN_VERSION) -f /source markdown -md /spec --md-check

.PHONY: schema-check
schema-check:
	cd tools && ./schema_check.sh

# Run all checks in order of speed / likely failure.
.PHONY: check
check: misspell markdownlint markdown-link-check
	@echo "All checks complete"

# Attempt to fix issues / regenerate tables.
.PHONY: fix
fix: table-generation misspell-correction
	@echo "All autofixes complete"

# Attempt to install all the tools
.PHONY: install-tools
install-tools: $(MISSPELL) $(MARKDOWN_LINT) $(MARKDOWN_LINK_CHECK) $(MARKDOWN_TOC)
	@echo "All tools installed"
