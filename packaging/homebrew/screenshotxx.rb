# Homebrew cask for ScreenshotXX. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/screenshotxx.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "screenshotxx" do
  version "0.2.0"
  sha256 "fb5fa988e2703cb0c7b99992933c940035e091e9296ef27df03cb41324492590"

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
