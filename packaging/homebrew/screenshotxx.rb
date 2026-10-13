# Homebrew cask for ScreenshotXX. Lives in the tap repo (austinejose/homebrew-tap) as Casks/screenshotxx.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "screenshotxx" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_RELEASE"

  url "https://github.com/austinejose/screenshotxx/releases/download/v#{version}/ScreenshotXX-#{version}.dmg"
  name "ScreenshotXX"
  desc "Screenshot tool with a floating card and an annotation editor"
  homepage "https://github.com/austinejose/screenshotxx"

  depends_on macos: ">= :tahoe"

  app "ScreenshotXX.app"

  zap trash: [
    "~/Library/Preferences/com.austinejose.screenshotxx.plist",
    "~/Library/Logs/ScreenshotXX.log",
  ]
end
