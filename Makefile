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
#    make version        - show current version
#    make clean          — remove build artifacts
#
#  Configuration:
#    Copy env.example to .env and fill in your values,
#    or export them in your shell.
#
# ============================================================

# Load .env if it exists
-include .env

# Version from git tag (strips leading 'v')
VERSION       := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
# Semantic version (strips -dev, -rc, etc. for manifest)
SEMVER        := $(shell echo "$(VERSION)" | sed 's/-.*//')
VERSION_MAJOR := $(word 1,$(subst ., ,$(SEMVER)))
VERSION_MINOR := $(word 2,$(subst ., ,$(SEMVER)))
VERSION_BUILD := $(word 3,$(subst ., ,$(SEMVER)))

# Roku device settings
ROKU_IP      ?= 192.168.1.100
ROKU_USER    ?= rokudev
ROKU_PASS    ?=

# Telemetry settings
TELEMETRY_URL   ?=
TELEMETRY_TOKEN ?=

# Dev login credentials (optional — for dev builds only)
DEV_EMAIL    ?=
DEV_PASSWORD ?=

# Build settings
SRC_DIR      := src
BUILD_DIR    := build
STAGE_DIR    := $(BUILD_DIR)/stage
DIST_FILE    := $(BUILD_DIR)/fishtank.zip
EXCLUDES     := -x ".*" -x "*/.*" -x "README.md" -x "Makefile" -x ".env*" -x "build/*" -x "*.dev.brs"

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

.PHONY: build dev dev-deploy deploy install remove debug screenshot clean help version

## Build the sideloadable zip
build:
	@mkdir -p $(BUILD_DIR)
	@rm -rf $(STAGE_DIR)
	@cp -r $(SRC_DIR) $(STAGE_DIR)
	@echo "Building v$(VERSION)..."
	@# Inject version into manifest
	@sed -i 's|__VERSION_MAJOR__|$(VERSION_MAJOR)|' $(STAGE_DIR)/manifest
	@sed -i 's|__VERSION_MINOR__|$(VERSION_MINOR)|' $(STAGE_DIR)/manifest
	@sed -i 's|__VERSION_BUILD__|$(VERSION_BUILD)|' $(STAGE_DIR)/manifest
	@# Inject version into source files
	@sed -i 's|__VERSION__|$(VERSION)|g' $(STAGE_DIR)/components/ApiTask.brs
	@sed -i 's|__VERSION__|$(VERSION)|g' $(STAGE_DIR)/components/TelemetryTask.brs
	@# Inject telemetry config
	@sed -i 's|__TELEMETRY_URL__|$(TELEMETRY_URL)|g' $(STAGE_DIR)/components/TelemetryTask.brs
	@sed -i 's|__TELEMETRY_TOKEN__|$(TELEMETRY_TOKEN)|g' $(STAGE_DIR)/components/TelemetryTask.brs
	@# Package
	@cd $(STAGE_DIR) && zip -r ../fishtank.zip . $(EXCLUDES) -q
	@rm -rf $(STAGE_DIR)
	@echo "Built: $(DIST_FILE) v$(VERSION) ($$(du -h $(DIST_FILE) | cut -f1))"

## Dev build — auto-login with credentials from .env
dev:
	@mkdir -p $(BUILD_DIR)
	@rm -rf $(STAGE_DIR)
	@cp -r $(SRC_DIR) $(STAGE_DIR)
	@echo "Building DEV v$(VERSION)..."
	@# Swap in dev login screen
	@cp $(STAGE_DIR)/components/LoginScreen.dev.brs $(STAGE_DIR)/components/LoginScreen.brs
	@rm -f $(STAGE_DIR)/components/LoginScreen.dev.brs
	@# Inject dev credentials
	@sed -i 's|__DEV_EMAIL__|$(DEV_EMAIL)|g' $(STAGE_DIR)/components/LoginScreen.brs
	@sed -i 's|__DEV_PASSWORD__|$(DEV_PASSWORD)|g' $(STAGE_DIR)/components/LoginScreen.brs
	@# Inject version into manifest
	@sed -i 's|__VERSION_MAJOR__|$(VERSION_MAJOR)|' $(STAGE_DIR)/manifest
	@sed -i 's|__VERSION_MINOR__|$(VERSION_MINOR)|' $(STAGE_DIR)/manifest
	@sed -i 's|__VERSION_BUILD__|$(VERSION_BUILD)|' $(STAGE_DIR)/manifest
	@# Inject version into source files
	@sed -i 's|__VERSION__|$(VERSION)|g' $(STAGE_DIR)/components/ApiTask.brs
	@sed -i 's|__VERSION__|$(VERSION)|g' $(STAGE_DIR)/components/TelemetryTask.brs
	@# Inject telemetry config
	@sed -i 's|__TELEMETRY_URL__|$(TELEMETRY_URL)|g' $(STAGE_DIR)/components/TelemetryTask.brs
	@sed -i 's|__TELEMETRY_TOKEN__|$(TELEMETRY_TOKEN)|g' $(STAGE_DIR)/components/TelemetryTask.brs
	@# Package
	@cd $(STAGE_DIR) && zip -r ../fishtank.zip . $(EXCLUDES) -q
	@rm -rf $(STAGE_DIR)
	@echo "Built: $(DIST_FILE) v$(VERSION) ($$(du -h $(DIST_FILE) | cut -f1))"

## Dev build + sideload to Roku
dev-deploy: dev
	$(call check_roku_pass)
	@echo "Deploying DEV v$(VERSION) to $(ROKU_IP)..."
	@curl -s -S --digest \
		-F "mysubmit=Install" \
		-F "archive=@$(DIST_FILE)" \
		http://$(ROKU_IP)/plugin_install \
		-u $(ROKU_USER):$(ROKU_PASS) \
		-o /dev/null -w "HTTP %{http_code}\n"
	@echo "Deployed (dev) successfully."

## Build and sideload to Roku
deploy: build
	$(call check_roku_pass)
	@echo "Deploying v$(VERSION) to $(ROKU_IP)..."
	@curl -s -S --digest \
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
	@curl -s -S --digest \
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

## Capture a screenshot from Roku
screenshot:
	$(call check_roku_pass)
	@mkdir -p $(BUILD_DIR)
	@echo "Capturing screenshot..."
	@curl -s -S --digest \
		http://$(ROKU_IP)/pkgs/dev.jpg \
		-u $(ROKU_USER):$(ROKU_PASS) \
		-o $(BUILD_DIR)/screenshot_$$(date +%Y%m%d_%H%M%S).jpg
	@echo "Saved to $(BUILD_DIR)/"

## Show current version
version:
	@echo "$(VERSION)"

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
	@echo "  make dev         Build with auto-login (uses DEV_EMAIL/DEV_PASSWORD from .env)"
	@echo "  make dev-deploy  Dev build + sideload to Roku"
	@echo "  make remove      Uninstall from Roku"
	@echo "  make debug       Open telnet debug console"
	@echo "  make screenshot  Take a screenshot of the deployed app"
	@echo "  make version     Show current version from git tag"
	@echo "  make clean       Remove build artifacts"
	@echo ""
	@echo "  Configure via .env file (see env.example)"
	@echo ""
