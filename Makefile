PROJECT := ClearShot.xcodeproj
SCHEME  := ClearShot
DERIVED := build/DerivedData
APP     := $(DERIVED)/Build/Products/Debug/ClearShot.app
CORE    := Packages/ClearShotCore

.PHONY: gen build run stop core-test check clean release dmg

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
	-pkill -x ClearShot

run: build stop
	open $(APP)

release: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -derivedDataPath build/Release -quiet build

dmg: release
	scripts/make-dmg.sh

clean:
	rm -rf build $(CORE)/.build $(PROJECT)
