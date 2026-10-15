import AppKit

enum SoundPlayer {
    /// macOS's own sounds. Each falls back to a short system sound if Apple moves the file.
    private static let systemSounds = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/"

    static func playShutter() {
        play(systemSounds + "Grab.aif", fallback: "Pop")
    }

    /// The moment a recording really starts (after the countdown).
    static func playRecordStart() {
        play(systemSounds + "begin_record.caf", fallback: "Tink")
    }

    static func playRecordStop() {
        play(systemSounds + "end_record.caf", fallback: "Pop")
    }

    private static func play(_ path: String, fallback: String) {
        (NSSound(contentsOfFile: path, byReference: true) ?? NSSound(named: fallback))?.play()
    }
}
