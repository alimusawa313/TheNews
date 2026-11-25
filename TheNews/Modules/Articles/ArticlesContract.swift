import SwiftUI

// MARK: - VIPER contract

protocol ArticlesInteracting {
    func articlesPage(_ page: Int) async throws(APIError) -> Page<Article>
}

protocol ArticlesRouting {
    func open(_ article: Article)
}

// MARK: - Interactor

struct ArticlesInteractor: ArticlesInteracting {
    let source: NewsSource
    let repository: any NewsRepository

    func articlesPage(_ page: Int) async throws(APIError) -> Page<Article> {
        try await repository.articles(sourceID: source.id, page: page)
    }
}

// MARK: - Router

struct ArticlesRouter: ArticlesRouting {
    let category: NewsCategory
    let navigator: Navigator

    func open(_ article: Article) { navigator.push(.article(article, category)) }
}

// MARK: - Builder

enum ArticlesModule {
    static func build(source: NewsSource, category: NewsCategory, repository: any NewsRepository, navigator: Navigator) -> ArticlesView {
        ArticlesView(presenter: ArticlesPresenter(
            source: source,
            category: category,
            interactor: ArticlesInteractor(source: source, repository: repository),
            router: ArticlesRouter(category: category, navigator: navigator)
        ))
    }
}
