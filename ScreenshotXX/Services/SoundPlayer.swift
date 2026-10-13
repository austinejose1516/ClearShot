import AppKit

enum SoundPlayer {
    /// macOS's own screenshot sound. Falls back to a short system click if Apple moves the file.
    private static let shutterCandidates = [
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Grab.aif",
    ]

    static func playShutter() {
        let sound = shutterCandidates.lazy.compactMap { NSSound(contentsOfFile: $0, byReference: true) }.first
            ?? NSSound(named: "Pop")
        sound?.play()
    }
}
