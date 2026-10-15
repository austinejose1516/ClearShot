import Foundation

/// How a length of video reads: on the recording bar, the card's badge and the editor.
public enum VideoTime {
    /// "0:42", "1:05:03", or with decimals "0:03.2".
    public static func clock(_ seconds: Double, decimals: Bool = false) -> String {
        let seconds = max(0, seconds)
        let whole = Int(seconds)
        let hours = whole / 3600
        let minutes = whole / 60 % 60
        let rest = decimals ? String(format: "%04.1f", seconds - Double(whole / 60 * 60)) : String(format: "%02d", whole % 60)
        return hours > 0 ? String(format: "%d:%02d:", hours, minutes) + rest : "\(minutes):" + rest
    }

    /// "8.9 s" under a minute, else "1:42".
    public static func length(_ seconds: Double) -> String {
        seconds < 60 ? "\(seconds.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX")))) s" : clock(seconds)
    }
}
