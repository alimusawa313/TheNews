import Observation
import SwiftUI

/// Push destinations. Routers describe where to go; the factory builds it.
nonisolated enum AppRoute: Hashable, Sendable {
    case sources(NewsCategory)
    case articles(NewsSource, NewsCategory)
    case article(Article, NewsCategory)
    case search
}

nonisolated enum SheetRoute: String, Identifiable, Sendable {
    case settings
    var id: String { rawValue }
}

@Observable
final class Navigator {
    var path: [AppRoute] = []
    var sheet: SheetRoute?

    func push(_ route: AppRoute) { path.append(route) }
    func present(_ sheet: SheetRoute) { self.sheet = sheet }
    func dismissSheet() { sheet = nil }
}
