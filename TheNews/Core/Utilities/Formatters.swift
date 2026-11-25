import Foundation

nonisolated enum Formatters {
    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()

    static func timestamp(_ string: String?) -> Date? {
        guard let value = string?.nilIfBlank else { return nil }
        return (try? plain.parse(value)) ?? (try? withFraction.parse(value))
    }

    /// "2 hr. ago", or nil when unknown.
    static func relative(_ date: Date?, now: Date = .now) -> String? {
        guard let date else { return nil }
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(Locale(identifier: "en_US")))
    }

    /// "https://www.theverge.com/x" → "theverge.com"
    static func domain(of url: URL) -> String {
        let host = url.host() ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

nonisolated extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
