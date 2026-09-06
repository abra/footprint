FLUTTER ?= fvm flutter
DART ?= fvm dart

.PHONY: get format format-check analyze test verify integration run build-android build-ios

get:
	$(FLUTTER) pub get

format:
	$(DART) format lib packages test integration_test

format-check:
	$(DART) format --output=none --set-exit-if-changed lib packages test integration_test

analyze:
	$(FLUTTER) analyze --no-pub

test:
	$(FLUTTER) test --no-pub test packages

verify: format-check analyze test

integration:
	$(FLUTTER) test integration_test -d "$(DEVICE)"

run:
	$(FLUTTER) run

build-android:
	$(FLUTTER) build apk --debug

build-ios:
	$(FLUTTER) build ios --simulator
