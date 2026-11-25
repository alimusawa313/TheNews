import Foundation

/// Immutable state machine for endless scrolling. Every transition returns a
/// new value, which keeps presenters simple and makes behaviour easy to test.
nonisolated struct Paginator<Item: Identifiable & Sendable>: Sendable where Item.ID: Sendable {
    nonisolated enum Phase: Equatable, Sendable {
        case idle
        case loadingFirstPage
        case loadingNextPage
        case loaded
        case failedFirstPage(APIError)
        case failedNextPage(APIError)
    }

    /// Start fetching the next page when this many items remain below the fold.
    static var prefetchThreshold: Int { 6 }

    let items: [Item]
    let phase: Phase
    let currentPage: Int
    let totalResults: Int
    let hasMore: Bool

    init() {
        self.init(items: [], phase: .idle, currentPage: 0, totalResults: 0, hasMore: true)
    }

    private init(items: [Item], phase: Phase, currentPage: Int, totalResults: Int, hasMore: Bool) {
        self.items = items
        self.phase = phase
        self.currentPage = currentPage
        self.totalResults = totalResults
        self.hasMore = hasMore
    }

    var nextPage: Int { currentPage + 1 }
    var isEmpty: Bool { phase == .loaded && items.isEmpty }
    var isLoadingFirstPage: Bool { phase == .loadingFirstPage }
    var hasReachedEnd: Bool { phase == .loaded && !hasMore && !items.isEmpty }

    /// Scroll-driven loads only fire from a settled state; a failed next page
    /// requires an explicit retry so we never hammer a failing endpoint.
    var canLoadNextPage: Bool { phase == .loaded && hasMore }

    func shouldLoadMore(after item: Item) -> Bool {
        guard canLoadNextPage,
              let index = items.lastIndex(where: { $0.id == item.id }) else { return false }
        return index >= items.count - Self.prefetchThreshold
    }

    // MARK: Transitions

    /// Starts from scratch (initial load or after a filter change).
    func startingFirstPage() -> Paginator {
        Paginator(items: [], phase: .loadingFirstPage, currentPage: 0, totalResults: 0, hasMore: true)
    }

    /// Re-fetches page one while keeping the current items on screen.
    func startingRefresh() -> Paginator {
        Paginator(items: items, phase: .loadingFirstPage, currentPage: currentPage, totalResults: totalResults, hasMore: hasMore)
    }

    func startingNextPage() -> Paginator {
        Paginator(items: items, phase: .loadingNextPage, currentPage: currentPage, totalResults: totalResults, hasMore: hasMore)
    }

    /// Appends a page, dropping duplicates (TMDB can repeat items across pages).
    func receiving(_ page: Page<Item>) -> Paginator {
        let baseItems = page.page <= 1 ? [] : items
        var seen = Set(baseItems.map(\.id))
        let newItems = page.items.filter { seen.insert($0.id).inserted }
        return Paginator(
            items: baseItems + newItems,
            phase: .loaded,
            currentPage: page.page,
            totalResults: page.totalResults,
            hasMore: page.hasMore && !page.items.isEmpty
        )
    }

    func failing(with error: APIError) -> Paginator {
        let phase: Phase
        switch (error, self.phase) {
        case (.cancelled, _):
            phase = items.isEmpty ? .idle : .loaded
        case (_, .loadingNextPage):
            phase = .failedNextPage(error)
        case _ where !items.isEmpty:
            // A failed refresh keeps the existing items visible.
            phase = .loaded
        default:
            phase = .failedFirstPage(error)
        }
        return Paginator(items: items, phase: phase, currentPage: currentPage, totalResults: totalResults, hasMore: hasMore)
    }
}
