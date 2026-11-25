import SwiftUI

// MARK: - VIPER contract

protocol SearchInteracting {
    /// Every source (cached). NewsAPI has no source search, so it is filtered locally.
    func allSources() async throws(APIError) -> [NewsSource]
    func searchArticles(query: String, page: Int) async throws(APIError) -> Page<Article>
}

protocol SearchRouting {
    func showArticles(for source: NewsSource)
    func open(_ article: Article)
}

// MARK: - Interactor

final class SearchInteractor: SearchInteracting {
    private let repository: any NewsRepository
    private var cache: [NewsSource]?

    init(repository: any NewsRepository) {
        self.repository = repository
    }

    func allSources() async throws(APIError) -> [NewsSource] {
        if let cache { return cache }
        let sources = try await repository.sources(category: nil)
        cache = sources
        return sources
    }

    func searchArticles(query: String, page: Int) async throws(APIError) -> Page<Article> {
        try await repository.searchArticles(query: query, page: page)
    }
}

// MARK: - Router

struct SearchRouter: SearchRouting {
    let navigator: Navigator

    func showArticles(for source: NewsSource) { navigator.push(.articles(source, source.category ?? .general)) }
    func open(_ article: Article) { navigator.push(.article(article, .general)) }
}

// MARK: - Builder

enum SearchModule {
    static func build(repository: any NewsRepository, navigator: Navigator) -> SearchView {
        SearchView(presenter: SearchPresenter(interactor: SearchInteractor(repository: repository), router: SearchRouter(navigator: navigator)))
    }
}
