# ============================================================
#  Fishtank.live Roku App — Makefile
# ============================================================
#
#  Usage:
#    make build          — zip the app for sideloading
#    make deploy         — build + sideload to Roku
#    make install        — alias for deploy
#    make remove         — uninstall from Roku
#    make debug          — open telnet debug console
#    make screenshot     — capture screenshot from Roku
#    make clean          — remove build artifacts
#
#  Configuration:
#    Copy env.example to .env and fill in your values,
#    or export them in your shell.
#
# ============================================================

# Load .env if it exists
-include .env

# Roku device settings
ROKU_IP      ?= 192.168.1.100
ROKU_USER    ?= rokudev
ROKU_PASS    ?= 

# Build settings
SRC_DIR      := src
BUILD_DIR    := build
DIST_FILE    := $(BUILD_DIR)/fishtank.zip
EXCLUDES     := -x ".*" -x "*/.*" -x "README.md" -x "Makefile" -x ".env*" -x "build/*"

# Validate Roku password is set for deploy targets
define check_roku_pass
	@if [ -z "$(ROKU_PASS)" ]; then \
		echo "Error: ROKU_PASS not set. Add it to .env or export it."; \
		exit 1; \
	fi
endef

# ============================================================
#  Targets
# ============================================================

.PHONY: build deploy install remove debug clean help

## Build the sideloadable zip
build:
	@mkdir -p $(BUILD_DIR)
	@echo "Building $(DIST_FILE)..."
	@cd $(SRC_DIR) && zip -r ../$(DIST_FILE) . $(EXCLUDES) -q
	@echo "Built: $(DIST_FILE) ($$(du -h $(DIST_FILE) | cut -f1))"

## Build and sideload to Roku
deploy: build
	$(call check_roku_pass)
	@echo "Deploying to $(ROKU_IP)..."
	@curl -s -S \
		-F "mysubmit=Install" \
		-F "archive=@$(DIST_FILE)" \
		http://$(ROKU_IP)/plugin_install \
		-u $(ROKU_USER):$(ROKU_PASS) \
		-o /dev/null -w "HTTP %{http_code}\n"
	@echo "Deployed successfully."

## Alias for deploy
install: deploy

## Remove app from Roku
remove:
	$(call check_roku_pass)
	@echo "Removing app from $(ROKU_IP)..."
	@curl -s -S \
		-F "mysubmit=Delete" \
		-F "archive=" \
		http://$(ROKU_IP)/plugin_install \
		-u $(ROKU_USER):$(ROKU_PASS) \
		-o /dev/null -w "HTTP %{http_code}\n"
	@echo "Removed."

## Open telnet debug console
debug:
	@echo "Connecting to $(ROKU_IP):8085..."
	@echo "(Use Ctrl+] then 'quit' to exit)"
	@telnet $(ROKU_IP) 8085

## Remove build artifacts
clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned."

## Show help
help:
	@echo ""
	@echo "  Fishtank.live Roku App"
	@echo "  ======================"
	@echo ""
	@echo "  make build       Build the sideloadable zip"
	@echo "  make deploy      Build + sideload to Roku"
	@echo "  make remove      Uninstall from Roku"
	@echo "  make debug       Open telnet debug console"
	@echo "  make clean       Remove build artifacts"
	@echo ""
	@echo "  Configure via .env file (see env.example)"
	@echo ""
