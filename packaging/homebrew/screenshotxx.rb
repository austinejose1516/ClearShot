# Homebrew cask for ScreenshotXX. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/screenshotxx.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "screenshotxx" do
  version "0.1.0"
  sha256 "739951da68bd09245532e83123326d0f386b5163b463f83f7e3940cfdf1526f3"

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
