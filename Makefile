# CrowdSec Makefile
# Provides common build, test, and development targets

SHELL := /bin/bash

# Go parameters
GOCMD   := go
GOBUILD := $(GOCMD) build
GOCLEAN := $(GOCMD) clean
GOTEST  := $(GOCMD) test
GOGET   := $(GOCMD) get
GOMOD   := $(GOCMD) mod

# Build info
BUILD_VERSION  ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_COMMIT   ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIMESTAMP ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Binary names
CROWDSEC_BIN  := crowdsec
CSCLI_BIN     := cscli

# Directories
CMD_DIR       := ./cmd
BUILD_DIR     := ./build
DIST_DIR      := ./dist

# Linker flags
LD_FLAGS := -ldflags "-X github.com/crowdsecurity/crowdsec/pkg/cwversion.Version=$(BUILD_VERSION) \
	-X github.com/crowdsecurity/crowdsec/pkg/cwversion.BuildDate=$(BUILD_TIMESTAMP) \
	-X github.com/crowdsecurity/crowdsec/pkg/cwversion.Commit=$(BUILD_COMMIT)"

.PHONY: all build build-crowdsec build-cscli clean test lint fmt vet tidy help

## all: Build all binaries
all: build

## build: Build both crowdsec and cscli binaries
build: build-crowdsec build-cscli

## build-crowdsec: Build the crowdsec daemon binary
build-crowdsec:
	@echo "Building crowdsec $(BUILD_VERSION)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(LD_FLAGS) -o $(BUILD_DIR)/$(CROWDSEC_BIN) $(CMD_DIR)/crowdsec

## build-cscli: Build the cscli command-line tool
build-cscli:
	@echo "Building cscli $(BUILD_VERSION)..."
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(LD_FLAGS) -o $(BUILD_DIR)/$(CSCLI_BIN) $(CMD_DIR)/crowdsec-cli

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(GOCLEAN)
	@rm -rf $(BUILD_DIR) $(DIST_DIR)

## test: Run all unit tests
test:
	@echo "Running tests..."
	$(GOTEST) -v -race ./...

## test-coverage: Run tests with coverage report
test-coverage:
	@echo "Running tests with coverage..."
	$(GOTEST) -v -race -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

## lint: Run golangci-lint
lint:
	@echo "Running linter..."
	@which golangci-lint > /dev/null || (echo "golangci-lint not found, install it from https://golangci-lint.run" && exit 1)
	golangci-lint run ./...

## fmt: Format Go source files
fmt:
	@echo "Formatting code..."
	$(GOCMD) fmt ./...

## vet: Run go vet
vet:
	@echo "Running go vet..."
	$(GOCMD) vet ./...

## tidy: Tidy go module dependencies
tidy:
	@echo "Tidying modules..."
	$(GOMOD) tidy

## release: Build release binaries for multiple platforms
release:
	@echo "Building release binaries..."
	@mkdir -p $(DIST_DIR)
	GOOS=linux   GOARCH=amd64 $(GOBUILD) $(LD_FLAGS) -o $(DIST_DIR)/$(CROWDSEC_BIN)-linux-amd64   $(CMD_DIR)/crowdsec
	GOOS=linux   GOARCH=arm64 $(GOBUILD) $(LD_FLAGS) -o $(DIST_DIR)/$(CROWDSEC_BIN)-linux-arm64   $(CMD_DIR)/crowdsec
	GOOS=darwin  GOARCH=amd64 $(GOBUILD) $(LD_FLAGS) -o $(DIST_DIR)/$(CROWDSEC_BIN)-darwin-amd64  $(CMD_DIR)/crowdsec
	GOOS=windows GOARCH=amd64 $(GOBUILD) $(LD_FLAGS) -o $(DIST_DIR)/$(CROWDSEC_BIN)-windows-amd64.exe $(CMD_DIR)/crowdsec

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':' | sed -e 's/^/ /'
