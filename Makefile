SWIFT_PACKAGE := SeismoscopeKit
XCODE_PROJECT := Seismoscope.xcodeproj
XCODE_SCHEME := Seismoscope
SIMULATOR ?= iPhone 17

.PHONY: build test test-package test-app clean run

build:
	xcodebuild build \
		-scheme $(XCODE_SCHEME) \
		-project $(XCODE_PROJECT) \
		-destination 'generic/platform=iOS' \
		CODE_SIGNING_ALLOWED=NO

test: test-package test-app

test-package:
	swift test --package-path $(SWIFT_PACKAGE)

test-app:
	xcodebuild test \
		-scheme $(XCODE_SCHEME) \
		-project $(XCODE_PROJECT) \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		CODE_SIGNING_ALLOWED=NO

run:
	swift run

clean:
	swift package --package-path $(SWIFT_PACKAGE) clean
