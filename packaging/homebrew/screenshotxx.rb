# Homebrew cask for ScreenshotXX. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/screenshotxx.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "screenshotxx" do
  version "0.4.0"
  sha256 "ceccdd0e143fc4a8ad0234c927b2e36691a0ec55931f2b2326a3d9365991e472"

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
