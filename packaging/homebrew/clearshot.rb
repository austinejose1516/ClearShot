# Homebrew cask for ClearShot. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/clearshot.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "clearshot" do
  version "0.10.0"
  sha256 "437913ff846e83fe9f4be2b5f22a6c85a95f7dc21053e9a750052d6b7dd9249a"

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
