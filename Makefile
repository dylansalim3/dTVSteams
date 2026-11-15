.PHONY: all help install dev dev-tv build build-prod preview preview-web preview-tv test lint clean

# Default target
all: help

help:
	@echo "dTVSteams Build & Development System"
	@echo "====================================="
	@echo "Available make targets:"
	@echo "  make dev          Start development server for Web App (http://localhost:8000)"
	@echo "  make dev-tv       Start development server for 10-Foot TV App (http://localhost:8100)"
	@echo "  make build        Build production artifacts into ./dist/"
	@echo "  make build-prod   Alias for make build"
	@echo "  make preview      Preview production portal at http://localhost:5000"
	@echo "  make preview-web  Preview production Web App at http://localhost:8000"
	@echo "  make preview-tv   Preview production TV App at http://localhost:8100"
	@echo "  make test         Run test suite with Vitest and coverage"
	@echo "  make lint         Run TypeScript linting and type checking"
	@echo "  make install      Install project dependencies"
	@echo "  make clean        Remove build artifacts and coverage reports"

install:
	npm install

dev:
	npm run dev

dev-tv:
	npm run dev:tv

build:
	npm run build

build-prod: build

preview:
	npm run preview

preview-web:
	npm run preview:web

preview-tv:
	npm run preview:tv

test:
	npm test

lint:
	npm run lint

clean:
	node -e "const fs = require('fs'); ['dist', 'coverage'].forEach(d => fs.rmSync(d, { recursive: true, force: true })); console.log('Cleaned dist and coverage');"
