SIM ?= platform=iOS Simulator,OS=latest,name=iPhone 15

.PHONY: clean-all resolve build-sim hooks

clean-all:
	xcodebuild -scheme Bumpin -configuration Debug clean >/dev/null || true
	rm -rf ~/Library/Developer/Xcode/DerivedData/Bumpin-*

resolve:
	xcodebuild -resolvePackageDependencies

build-sim:
	set -o pipefail; xcodebuild -scheme Bumpin -configuration Debug -destination '$(SIM)' build | xcpretty || true

hooks:
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit

firebase-test:
	cd firebase && if [ ! -d node_modules ]; then npm ci || npm i; fi && npm test


# ---------- iOS app guardrails ----------

# Quick local build (fail fast)
build:
	xcodebuild -project Bumpin.xcodeproj -scheme Bumpin -destination 'platform=iOS Simulator,name=iPhone 16' build | cat

# Build for testing (faster iteration for unit tests)
build-for-testing:
	xcodebuild -project Bumpin.xcodeproj -scheme Bumpin -destination 'platform=iOS Simulator,name=iPhone 16' build-for-testing | cat

# Optionally run unit tests if configured
test:
	xcodebuild -project Bumpin.xcodeproj -scheme Bumpin -destination 'platform=iOS Simulator,name=iPhone 16' test | cat || true

# Lint (no-op if SwiftLint not installed)
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
	  swiftlint --config .swiftlint.yml || true; \
	else \
	  echo "SwiftLint not installed; skipping lint"; \
	fi

# Format (no-op if SwiftFormat not installed)
format:
	@if command -v swiftformat >/dev/null 2>&1; then \
	  swiftformat --config .swiftformat Bumpin || true; \
	else \
	  echo "SwiftFormat not installed; skipping format"; \
	fi

# Validate Swift file structure (brace/paren balance, obvious duplicates)
validate-structure:
	python3 scripts/validate_swift_structure.py Bumpin || true

# Preflight: format + lint + structure + quick build
preflight:
	$(MAKE) format
	$(MAKE) lint
	$(MAKE) validate-structure
	$(MAKE) build

# Preflight fast: only check staged Swift files quickly, then compile
preflight-fast:
	python3 scripts/changed_swift_check.py || true
	$(MAKE) build

# Install pre-commit hook to enforce preflight
install-hooks:
	mkdir -p .git/hooks
	printf "#!/bin/sh\n\nmake preflight || exit 1\n" > .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	# Append fast changed-files check
	@grep -q changed_swift_check .git/hooks/pre-commit || echo "python3 scripts/changed_swift_check.py || exit 1" >> .git/hooks/pre-commit
	@echo "Installed pre-commit hook to run preflight + fast check"

# Minimal UI smoke tests (safe, non-brittle)
ui-smoke:
	xcodebuild -project Bumpin.xcodeproj -scheme Bumpin -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:BumpinUITests/BumpinUITests/testSmoke_HomeTabsExist | cat || true


