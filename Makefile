APP_NAME := OpenRouterCredits

.PHONY: build test check check-strings preview dmg run install clean

build:
	./scripts/build-app.sh

test:
	swift test

check: check-strings test

check-strings:
	./scripts/check-strings.sh

preview:
	swift run CreditsPreviewRender docs/previews

dmg: build
	./scripts/build-dmg.sh

run: build
	open "build/$(APP_NAME).app"

install: build
	./scripts/install.sh

clean:
	rm -rf .build build
