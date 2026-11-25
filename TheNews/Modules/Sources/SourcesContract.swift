import SwiftUI

// MARK: - VIPER contract

protocol SourcesInteracting {
    /// One page of the category's sources. NewsAPI returns them all at once,
    /// so the interactor caches the list and pages through it locally.
    func sourcesPage(_ page: Int, refresh: Bool) async throws(APIError) -> Page<NewsSource>
}

protocol SourcesRouting {
    func showArticles(for source: NewsSource)
}

// MARK: - Interactor

final class SourcesInteractor: SourcesInteracting {
    static let pageSize = 6

    private let category: NewsCategory
    private let repository: any NewsRepository
    private var cache: [NewsSource]?

    init(category: NewsCategory, repository: any NewsRepository) {
        self.category = category
        self.repository = repository
    }

    func sourcesPage(_ page: Int, refresh: Bool) async throws(APIError) -> Page<NewsSource> {
        if refresh || cache == nil {
            cache = try await repository.sources(category: category)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        let all = cache ?? []
        let start = (page - 1) * Self.pageSize
        let slice = start < all.count ? Array(all[start..<min(start + Self.pageSize, all.count)]) : []
        return Page(page: page, items: slice, totalResults: all.count, pageSize: Self.pageSize)
    }
}

// MARK: - Router

struct SourcesRouter: SourcesRouting {
    let category: NewsCategory
    let navigator: Navigator

    func showArticles(for source: NewsSource) { navigator.push(.articles(source, category)) }
}

// MARK: - Builder

enum SourcesModule {
    static func build(category: NewsCategory, repository: any NewsRepository, navigator: Navigator) -> SourcesView {
        SourcesView(presenter: SourcesPresenter(
            category: category,
            interactor: SourcesInteractor(category: category, repository: repository),
            router: SourcesRouter(category: category, navigator: navigator)
        ))
    }
}
