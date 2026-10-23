# Homebrew cask for ClearShot. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/clearshot.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "clearshot" do
  version "0.15.0"
  sha256 "05380a28d178fa8ba277ab8e6a2e41f3c5c5173b7ed457d592337279954832b7"

  url "https://github.com/austinejose1516/ClearShot/releases/download/v#{version}/ClearShot-#{version}.dmg"
  name "ClearShot"
  desc "Screenshot tool with a floating card and an annotation editor"
  homepage "https://github.com/austinejose1516/ClearShot"

  depends_on macos: :tahoe

  app "ClearShot.app"

  zap trash: [
    "~/Library/Preferences/com.austinejose.clearshot.plist",
    "~/Library/Logs/ClearShot.log",
  ]
end
