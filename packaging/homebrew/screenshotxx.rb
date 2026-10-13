# Homebrew cask for ScreenshotXX. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/screenshotxx.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "screenshotxx" do
  version "0.3.0"
  sha256 "41b65b41910f33a1e77a924f47bf9baaac8dda5c45f7145056c903e7788b9ead"

  url "https://github.com/austinejose1516/ScreenshotXX/releases/download/v#{version}/ScreenshotXX-#{version}.dmg"
  name "ScreenshotXX"
  desc "Screenshot tool with a floating card and an annotation editor"
  homepage "https://github.com/austinejose1516/ScreenshotXX"

  depends_on macos: :tahoe

  app "ScreenshotXX.app"

  zap trash: [
    "~/Library/Preferences/com.austinejose.screenshotxx.plist",
    "~/Library/Logs/ScreenshotXX.log",
  ]
end
