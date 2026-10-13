PROJECT := ScreenshotXX.xcodeproj
SCHEME  := ScreenshotXX
DERIVED := build/DerivedData
APP     := $(DERIVED)/Build/Products/Debug/ScreenshotXX.app
CORE    := Packages/ScreenshotXXCore

.PHONY: gen build run stop core-test check clean

Local.xcconfig:
	@printf '// Per-machine signing overrides (git-ignored).\n// After adding your Apple ID in Xcode > Settings > Accounts, set:\n// CODE_SIGN_STYLE = Automatic\n// CODE_SIGN_IDENTITY = Apple Development\n// DEVELOPMENT_TEAM = YOURTEAMID\n' > $@

gen: Local.xcconfig
	xcodegen generate --quiet

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) -quiet build

core-test:
	swift test --package-path $(CORE)

check: core-test build

stop:
	-pkill -x ScreenshotXX

run: build stop
	open $(APP)

clean:
	rm -rf build $(CORE)/.build $(PROJECT)
