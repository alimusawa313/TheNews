import Observation
import SwiftUI

@Observable
final class ArticlesPresenter {
    let source: NewsSource
    let category: NewsCategory
    private(set) var paginator = Paginator<Article>()
    var refreshError: APIError?

    private let interactor: any ArticlesInteracting
    private let router: any ArticlesRouting
    private var generation = 0

    init(source: NewsSource, category: NewsCategory, interactor: any ArticlesInteracting, router: any ArticlesRouting) {
        self.source = source
        self.category = category
        self.interactor = interactor
        self.router = router
    }

    var articles: [Article] { paginator.items }

    func onAppear() async {
        guard paginator.phase == .idle else { return }
        await loadFirstPage()
    }

    func retry() async { await loadFirstPage() }

    func refresh() async {
        generation += 1
        let token = generation
        let hadItems = !paginator.items.isEmpty
        paginator = paginator.startingRefresh()
        do {
            let page = try await interactor.articlesPage(1)
            guard token == generation else { return }
            paginator = paginator.receiving(page)
        } catch {
            guard token == generation else { return }
            if hadItems, error != .cancelled { refreshError = error }
            paginator = paginator.failing(with: error)
        }
    }

    func loadMoreIfNeeded(after article: Article) async {
        guard paginator.shouldLoadMore(after: article) else { return }
        await loadNextPage()
    }

    func retryNextPage() async {
        guard case .failedNextPage = paginator.phase else { return }
        await loadNextPage()
    }

    func didSelect(_ article: Article) { router.open(article) }

    private func loadFirstPage() async {
        generation += 1
        paginator = paginator.startingFirstPage()
        await fetch(page: 1, token: generation)
    }

    private func loadNextPage() async {
        let page = paginator.nextPage
        paginator = paginator.startingNextPage()
        await fetch(page: page, token: generation)
    }

    private func fetch(page: Int, token: Int) async {
        do {
            let result = try await interactor.articlesPage(page)
            guard token == generation else { return }
            paginator = paginator.receiving(result)
        } catch {
            guard token == generation else { return }
            // The free plan caps results; past the cap the column simply ends.
            if error == .resultsLimitReached, page > 1 {
                paginator = paginator.startingNextPage().receiving(
                    Page(page: page, items: [], totalResults: paginator.totalResults, pageSize: NewsEndpoint.pageSize)
                )
            } else {
                paginator = paginator.failing(with: error)
            }
        }
    }
}
