import Observation
import SwiftUI

@Observable
final class SourcesPresenter {
    let category: NewsCategory
    private(set) var paginator = Paginator<NewsSource>()
    var refreshError: APIError?

    private let interactor: any SourcesInteracting
    private let router: any SourcesRouting
    private var generation = 0

    init(category: NewsCategory, interactor: any SourcesInteracting, router: any SourcesRouting) {
        self.category = category
        self.interactor = interactor
        self.router = router
    }

    var sources: [NewsSource] { paginator.items }

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
            let page = try await interactor.sourcesPage(1, refresh: true)
            guard token == generation else { return }
            paginator = paginator.receiving(page)
        } catch {
            guard token == generation else { return }
            if hadItems, error != .cancelled { refreshError = error }
            paginator = paginator.failing(with: error)
        }
    }

    func loadMoreIfNeeded(after source: NewsSource) async {
        guard paginator.shouldLoadMore(after: source) else { return }
        await loadNextPage()
    }

    func retryNextPage() async {
        guard case .failedNextPage = paginator.phase else { return }
        await loadNextPage()
    }

    func didSelect(_ source: NewsSource) { router.showArticles(for: source) }

    private func loadFirstPage() async {
        generation += 1
        paginator = paginator.startingFirstPage()
        await fetch(page: 1, refresh: true, token: generation)
    }

    private func loadNextPage() async {
        let page = paginator.nextPage
        paginator = paginator.startingNextPage()
        await fetch(page: page, refresh: false, token: generation)
    }

    private func fetch(page: Int, refresh: Bool, token: Int) async {
        do {
            let result = try await interactor.sourcesPage(page, refresh: refresh)
            guard token == generation else { return }
            paginator = paginator.receiving(result)
        } catch {
            guard token == generation else { return }
            paginator = paginator.failing(with: error)
        }
    }
}
