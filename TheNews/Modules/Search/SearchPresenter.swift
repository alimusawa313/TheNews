import Observation
import SwiftUI

@Observable
final class SearchPresenter {
    enum Tab: String, CaseIterable, Identifiable {
        case sources, articles
        var id: String { rawValue }
        var title: String { rawValue.uppercased() }
    }

    static let suggestions = ["BBC", "The Verge", "climate", "football", "AI", "markets"]

    var tab: Tab = .sources
    private(set) var query = ""
    private(set) var allSources: LoadState<[NewsSource]> = .idle
    private(set) var articles = Paginator<Article>()

    private let interactor: any SearchInteracting
    private let router: any SearchRouting
    private let debounce: Duration
    private var generation = 0

    init(interactor: any SearchInteracting, router: any SearchRouting, debounce: Duration = .milliseconds(400)) {
        self.interactor = interactor
        self.router = router
        self.debounce = debounce
    }

    var hasQuery: Bool { !query.isEmpty }

    var matchingSources: [NewsSource] {
        guard hasQuery, let sources = allSources.value else { return [] }
        return sources.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.domain.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: Intents

    func onAppear() async {
        guard allSources.isIdle else { return }
        await loadSources()
    }

    /// Called on every keystroke; the view's task is cancelled on the next one.
    func updateQuery(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != query else { return }
        query = trimmed
        generation += 1
        let token = generation
        guard !trimmed.isEmpty else {
            articles = Paginator()
            return
        }
        articles = articles.startingFirstPage()
        try? await Task.sleep(for: debounce)
        guard token == generation, !Task.isCancelled else { return }
        await fetchArticles(page: 1, token: token)
    }

    func retry() async {
        if allSources.error != nil { await loadSources() }
        if hasQuery, case .failedFirstPage = articles.phase {
            generation += 1
            articles = articles.startingFirstPage()
            await fetchArticles(page: 1, token: generation)
        }
    }

    func loadMoreIfNeeded(after article: Article) async {
        guard articles.shouldLoadMore(after: article) else { return }
        await loadNextArticles()
    }

    func retryNextPage() async {
        guard case .failedNextPage = articles.phase else { return }
        await loadNextArticles()
    }

    func didSelect(_ source: NewsSource) { router.showArticles(for: source) }
    func didSelect(_ article: Article) { router.open(article) }

    // MARK: Private

    private func loadSources() async {
        allSources = .loading
        do {
            let sources = try await interactor.allSources()
            allSources = .loaded(sources)
        } catch {
            allSources = error == .cancelled ? .idle : .failed(error)
        }
    }

    private func loadNextArticles() async {
        let page = articles.nextPage
        articles = articles.startingNextPage()
        await fetchArticles(page: page, token: generation)
    }

    private func fetchArticles(page: Int, token: Int) async {
        let currentQuery = query
        do {
            let result = try await interactor.searchArticles(query: currentQuery, page: page)
            guard token == generation else { return }
            articles = articles.receiving(result)
        } catch {
            guard token == generation else { return }
            if error == .resultsLimitReached, page > 1 {
                articles = articles.startingNextPage().receiving(Page(page: page, items: [], totalResults: articles.totalResults, pageSize: NewsEndpoint.pageSize))
            } else {
                articles = articles.failing(with: error)
            }
        }
    }
}
