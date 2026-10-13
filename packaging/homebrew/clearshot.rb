# Homebrew cask for ClearShot. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/clearshot.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "clearshot" do
  version "0.5.0"
  sha256 "ad631e68cb0e810afa7ff42b99377bb0b410d0b965cab71bc24e7191f806b9ac"

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
