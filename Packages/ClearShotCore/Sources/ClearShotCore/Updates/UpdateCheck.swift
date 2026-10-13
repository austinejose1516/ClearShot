import Foundation

/// A version like "0.2.0" or a tag like "v0.2.0". Missing parts count as zero, so "1.10" equals "1.10.0".
public struct AppVersion: Comparable, Sendable, CustomStringConvertible {
    /// Numbers with trailing zeros removed (at least one number).
    private let numbers: [Int]

    public init?(_ text: String) {
        let trimmed = text.lowercased().hasPrefix("v") ? String(text.dropFirst()) : text
        let pieces = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        var numbers: [Int] = []
        for piece in pieces {
            guard let number = Int(piece), number >= 0 else { return nil }
            numbers.append(number)
        }
        while numbers.count > 1, numbers.last == 0 { numbers.removeLast() }
        guard !numbers.isEmpty else { return nil }
        self.numbers = numbers
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.numbers.count, rhs.numbers.count)
        for index in 0..<count {
            let left = index < lhs.numbers.count ? lhs.numbers[index] : 0
            let right = index < rhs.numbers.count ? rhs.numbers[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    /// Always at least three parts: "0.3.0".
    public var description: String {
        (numbers + Array(repeating: 0, count: max(0, 3 - numbers.count))).map(String.init).joined(separator: ".")
    }
}

/// The decisions behind "Check for Updates": is the latest release newer, and is a background check due.
public enum UpdateCheck {
    public enum Result: Equatable, Sendable {
        case upToDate
        case available(String)
    }

    /// How often the automatic check runs.
    public static let interval: TimeInterval = 24 * 60 * 60

    public static func result(current: String, latestTag: String) -> Result {
        guard let latest = AppVersion(latestTag), let installed = AppVersion(current), latest > installed else {
            return .upToDate
        }
        return .available(latest.description)
    }

    public static func isDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= interval
    }
}
