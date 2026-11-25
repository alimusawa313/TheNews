import Foundation

/// NewsAPI's seven fixed categories, in poster order.
nonisolated enum NewsCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general, business, technology, science, health, sports, entertainment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Top Stories"
        case .business: "Business"
        case .technology: "Technology"
        case .science: "Science"
        case .health: "Health"
        case .sports: "Sports"
        case .entertainment: "Entertainment"
        }
    }

    var blurb: String {
        switch self {
        case .general: "The day’s biggest stories, from every desk."
        case .business: "Markets, companies, money and the economy."
        case .technology: "Software, gadgets, startups and the people behind them."
        case .science: "Space, climate, discovery and research."
        case .health: "Medicine, wellbeing and public health."
        case .sports: "Results, transfers and the stories behind the games."
        case .entertainment: "Film, television, music and culture."
        }
    }

    /// "01" … "07", the poster number.
    var number: String { String(format: "%02d", (Self.allCases.firstIndex(of: self) ?? 0) + 1) }
}
