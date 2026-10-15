# Homebrew cask for ClearShot. Lives in the tap repo (austinejose1516/homebrew-tap) as Casks/clearshot.rb.
# Update `version` and `sha256` (from the .dmg.sha256 file) on each release.
cask "clearshot" do
  version "0.7.0"
  sha256 "0b57db074a043b02827f598454fe0e25b37670aaa92740e46eba0be01ab85dc3"

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
