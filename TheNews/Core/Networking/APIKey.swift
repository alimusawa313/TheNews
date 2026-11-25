import Foundation

/// A NewsAPI key: 32 alphanumeric characters. Parsing rejects obviously
/// malformed input before any request is made.
nonisolated struct APIKey: Hashable, Sendable {
    private static let length = 32

    let value: String

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == Self.length,
              trimmed.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        value = trimmed
    }

    /// "••••••••ab12", safe to show in Settings.
    var masked: String { "••••••••" + value.suffix(4) }
}
