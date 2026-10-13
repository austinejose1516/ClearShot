PROJECT := ScreenshotXX.xcodeproj
SCHEME  := ScreenshotXX
DERIVED := build/DerivedData
APP     := $(DERIVED)/Build/Products/Debug/ScreenshotXX.app
CORE    := Packages/ScreenshotXXCore

.PHONY: gen build run stop core-test check clean

Local.xcconfig:
	@printf '%s\n' \
	  '// Per-machine signing overrides (git-ignored).' \
	  '// 1. Xcode > Settings > Accounts > add Apple ID > Manage Certificates > + > Apple Development' \
	  '// 2. Terminal: security set-key-partition-list -S apple-tool:,apple:,codesign: -s ~/Library/Keychains/login.keychain-db' \
	  '// 3. Team ID = OU field of that certificate: security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject' \
	  '// CODE_SIGN_STYLE = Manual' \
	  '// CODE_SIGN_IDENTITY = Apple Development' \
	  '// DEVELOPMENT_TEAM = YOURTEAMID' \
	  '// PROVISIONING_PROFILE_SPECIFIER =' > $@

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
