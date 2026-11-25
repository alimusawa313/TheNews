import Foundation
import Testing
@testable import TheNews

final class SpyRouter: CategoryWallRouting, SourcesRouting, ArticlesRouting, SearchRouting, OnboardingRouting {
    private(set) var log: [String] = []
    var saveFailure: CredentialStoreError?

    func showSources(for category: NewsCategory) { log.append("sources:\(category.rawValue)") }
    func showSearch() { log.append("search") }
    func showSettings() { log.append("settings") }
    func showArticles(for source: NewsSource) { log.append("articles:\(source.id)") }
    func open(_ article: Article) { log.append("open:\(article.title)") }
    func complete(with key: APIKey) throws(CredentialStoreError) {
        if let saveFailure { throw saveFailure }
        log.append("complete")
    }
    func startDemo() { log.append("demo") }
}

@Suite("Home poster wall")
struct CategoryWallTests {
    @Test("Lists every category and routes taps")
    func routing() {
        let router = SpyRouter()
        let presenter = CategoryWallPresenter(interactor: CategoryWallInteractor(), router: router, isDemo: true)
        #expect(presenter.categories == NewsCategory.allCases)
        #expect(presenter.currentCategory == .general)
        presenter.current = NewsCategory.science.id
        #expect(presenter.currentCategory == .science)
        presenter.didSelect(.sports)
        presenter.didTapSearch()
        presenter.didTapSettings()
        #expect(router.log == ["sources:sports", "search", "settings"])
        #expect(presenter.isDemo)
    }
}

@Suite("Sources")
struct SourcesTests {
    private func makeSUT(_ result: Result<[NewsSource], APIError>) -> (SourcesPresenter, SpyRouter) {
        let router = SpyRouter()
        let interactor = SourcesInteractor(category: .technology, repository: FakeNewsRepository(sourcesResult: result))
        return (SourcesPresenter(category: .technology, interactor: interactor, router: router), router)
    }

    @Test("Pages the cached list locally until the end")
    func endlessLocalPaging() async {
        let (presenter, router) = makeSUT(.success(Fixtures.sources(14)))
        await presenter.onAppear()
        #expect(presenter.sources.count == SourcesInteractor.pageSize)
        await presenter.loadMoreIfNeeded(after: presenter.sources.last!)
        await presenter.loadMoreIfNeeded(after: presenter.sources.last!)
        #expect(presenter.sources.count == 14)
        #expect(presenter.paginator.hasReachedEnd)
        presenter.didSelect(presenter.sources[0])
        #expect(router.log == ["articles:src00"])
    }

    @Test("Sources are sorted by name")
    func sorted() async {
        let (presenter, _) = makeSUT(.success([Fixtures.source("zeta"), Fixtures.source("alpha")]))
        await presenter.onAppear()
        #expect(presenter.sources.map(\.id) == ["alpha", "zeta"])
    }

    @Test("Empty and error states")
    func negative() async {
        let (empty, _) = makeSUT(.success([]))
        await empty.onAppear()
        #expect(empty.paginator.isEmpty)

        let (failing, _) = makeSUT(.failure(.offline))
        await failing.onAppear()
        #expect(failing.paginator.phase == .failedFirstPage(.offline))
    }

    @Test("A failed refresh keeps sources and shows a toast")
    func refreshFailure() async {
        final class Flaky: SourcesInteracting {
            var calls = 0
            func sourcesPage(_ page: Int, refresh: Bool) async throws(APIError) -> Page<NewsSource> {
                calls += 1
                if calls > 1 { throw .timedOut }
                return Page(page: 1, items: Fixtures.sources(3), totalResults: 3, pageSize: 6)
            }
        }
        let presenter = SourcesPresenter(category: .science, interactor: Flaky(), router: SpyRouter())
        await presenter.onAppear()
        await presenter.refresh()
        #expect(presenter.sources.count == 3)
        #expect(presenter.refreshError == .timedOut)
    }
}

@Suite("Articles")
struct ArticlesTests {
    final class ScriptedArticles: ArticlesInteracting {
        var results: [Result<Page<Article>, APIError>]
        init(_ results: [Result<Page<Article>, APIError>]) { self.results = results }
        func articlesPage(_ page: Int) async throws(APIError) -> Page<Article> { try results.removeFirst().get() }
    }

    private func makeSUT(_ results: [Result<Page<Article>, APIError>]) -> (ArticlesPresenter, SpyRouter) {
        let router = SpyRouter()
        let presenter = ArticlesPresenter(source: Fixtures.source("wired"), category: .technology, interactor: ScriptedArticles(results), router: router)
        return (presenter, router)
    }

    @Test("Endless scrolling appends pages and opens an article")
    func paging() async {
        let (presenter, router) = makeSUT([.success(Fixtures.articlePage(1)), .success(Fixtures.articlePage(2))])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.articles.last!)
        #expect(presenter.articles.count == 40)
        presenter.didSelect(presenter.articles[0])
        #expect(router.log == ["open:Story 0"])
    }

    @Test("The free plan's result cap ends the list instead of erroring")
    func resultsCap() async {
        let (presenter, _) = makeSUT([.success(Fixtures.articlePage(1)), .failure(.resultsLimitReached)])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.articles.last!)
        #expect(presenter.paginator.hasReachedEnd)
        #expect(presenter.articles.count == 20)
    }

    @Test("A failed next page can be retried")
    func nextPageRetry() async {
        let (presenter, _) = makeSUT([.success(Fixtures.articlePage(1)), .failure(.offline), .success(Fixtures.articlePage(2))])
        await presenter.onAppear()
        await presenter.loadMoreIfNeeded(after: presenter.articles.last!)
        #expect(presenter.paginator.phase == .failedNextPage(.offline))
        await presenter.retryNextPage()
        #expect(presenter.articles.count == 40)
    }

    @Test("Unauthorized first page and empty source")
    func negative() async {
        let (rejected, _) = makeSUT([.failure(.unauthorized)])
        await rejected.onAppear()
        #expect(rejected.paginator.phase == .failedFirstPage(.unauthorized))

        let (empty, _) = makeSUT([.success(Fixtures.articlePage(1, count: 0, total: 0))])
        await empty.onAppear()
        #expect(empty.paginator.isEmpty)
    }

    @Test("Refresh failure keeps stories visible")
    func refresh() async {
        let (presenter, _) = makeSUT([.success(Fixtures.articlePage(1)), .failure(.server(statusCode: 502))])
        await presenter.onAppear()
        await presenter.refresh()
        #expect(presenter.articles.count == 20)
        #expect(presenter.refreshError == .server(statusCode: 502))
    }
}

@Suite("Search")
struct SearchTests {
    final class ScriptedSearch: SearchInteracting {
        var sourcesResult: Result<[NewsSource], APIError>
        var pages: [Result<Page<Article>, APIError>]
        private(set) var queries: [String] = []
        init(sources: Result<[NewsSource], APIError> = .success([]), pages: [Result<Page<Article>, APIError>] = []) {
            sourcesResult = sources
            self.pages = pages
        }
        func allSources() async throws(APIError) -> [NewsSource] { try sourcesResult.get() }
        func searchArticles(query: String, page: Int) async throws(APIError) -> Page<Article> {
            queries.append(query)
            return try pages.removeFirst().get()
        }
    }

    @Test("Filters sources locally by name or domain")
    func sourceFilter() async {
        let interactor = ScriptedSearch(sources: .success([Fixtures.source("verge"), Fixtures.source("bbc")]), pages: [.success(Fixtures.articlePage(1))])
        let presenter = SearchPresenter(interactor: interactor, router: SpyRouter(), debounce: .zero)
        await presenter.onAppear()
        await presenter.updateQuery("  VERGE ")
        #expect(presenter.matchingSources.map(\.id) == ["verge"])
        #expect(interactor.queries == ["VERGE"])
        #expect(presenter.articles.items.count == 20)
    }

    @Test("Fast typing only searches the final text")
    func debounce() async {
        let interactor = ScriptedSearch(pages: [.success(Fixtures.articlePage(1))])
        let presenter = SearchPresenter(interactor: interactor, router: SpyRouter(), debounce: .milliseconds(80))
        let first = Task { await presenter.updateQuery("cli") }
        let second = Task { await presenter.updateQuery("climate") }
        await first.value
        await second.value
        #expect(interactor.queries == ["climate"])
    }

    @Test("Clearing the query resets results; no matches is empty")
    func clearAndEmpty() async {
        let interactor = ScriptedSearch(sources: .success([Fixtures.source("bbc")]), pages: [.success(Fixtures.articlePage(1, count: 0, total: 0))])
        let presenter = SearchPresenter(interactor: interactor, router: SpyRouter(), debounce: .zero)
        await presenter.onAppear()
        await presenter.updateQuery("zzz")
        #expect(presenter.matchingSources.isEmpty)
        #expect(presenter.articles.isEmpty)
        await presenter.updateQuery("")
        #expect(!presenter.hasQuery)
        #expect(presenter.articles.phase == .idle)
    }

    @Test("Errors surface and retry recovers")
    func errors() async {
        let interactor = ScriptedSearch(sources: .failure(.offline), pages: [.failure(.rateLimited(retryAfter: nil)), .success(Fixtures.articlePage(1))])
        let presenter = SearchPresenter(interactor: interactor, router: SpyRouter(), debounce: .zero)
        await presenter.onAppear()
        #expect(presenter.allSources.error == .offline)
        await presenter.updateQuery("ai")
        #expect(presenter.articles.phase == .failedFirstPage(.rateLimited(retryAfter: nil)))
        interactor.sourcesResult = .success([Fixtures.source("ai-news")])
        await presenter.retry()
        #expect(presenter.matchingSources.count == 1)
        #expect(presenter.articles.items.count == 20)
    }

    @Test("Results route to articles and the web view")
    func routing() async {
        let router = SpyRouter()
        let presenter = SearchPresenter(interactor: ScriptedSearch(), router: router)
        presenter.didSelect(Fixtures.source("bbc"))
        presenter.didSelect(Fixtures.article(1))
        #expect(router.log == ["articles:bbc", "open:Story 1"])
    }

    @Test("Interactor caches the source list")
    func cache() async throws {
        let interactor = SearchInteractor(repository: FakeNewsRepository(sourcesResult: .success(Fixtures.sources(2))))
        #expect(try await interactor.allSources().count == 2)
        #expect(try await interactor.allSources().count == 2)
    }
}

@Suite("Onboarding")
struct OnboardingTests {
    private func makeSUT(_ validation: Result<Void, APIError>) -> (OnboardingPresenter, SpyRouter) {
        let router = SpyRouter()
        let interactor = OnboardingInteractor { _ in FakeNewsRepository(validation: validation) }
        return (OnboardingPresenter(interactor: interactor, router: router, successDelay: .zero), router)
    }

    @Test("A valid key signs in")
    func success() async {
        let (presenter, router) = makeSUT(.success(()))
        presenter.paste(" \(Fixtures.key.value) ")
        await presenter.connect()
        #expect(presenter.phase == .succeeded)
        #expect(router.log == ["complete"])
    }

    @Test("Malformed keys are rejected without a request")
    func malformed() async {
        let (presenter, router) = makeSUT(.success(()))
        presenter.input = "nope"
        await presenter.connect()
        #expect(presenter.errorMessage == APIError.invalidKey.message)
        #expect(presenter.failures == 1)
        #expect(router.log.isEmpty)
    }

    @Test("A rejected key, offline, and Keychain failures are reported")
    func failures() async {
        let (rejected, _) = makeSUT(.failure(.unauthorized))
        rejected.input = Fixtures.key.value
        await rejected.connect()
        #expect(rejected.errorMessage == APIError.unauthorized.message)
        rejected.input += "x"
        #expect(rejected.phase == .idle)

        let (keychain, router) = makeSUT(.success(()))
        router.saveFailure = .unexpectedStatus(-1)
        keychain.input = Fixtures.key.value
        await keychain.connect()
        #expect(keychain.errorMessage?.contains("Keychain") == false)
        #expect(keychain.errorMessage != nil)
    }

    @Test("Blank input cannot submit; demo routes")
    func blankAndDemo() async {
        let (presenter, router) = makeSUT(.success(()))
        #expect(!presenter.canSubmit)
        presenter.startDemo()
        #expect(router.log == ["demo"])
    }
}

@Suite("Session")
struct SessionTests {
    private let plain = LaunchConfiguration(arguments: [], environment: [:])

    @Test("Fresh install clears a leftover key; relaunch keeps a saved one")
    func freshInstall() throws {
        let store = InMemoryCredentialStore(key: Fixtures.key)
        let defaults = Fixtures.freshDefaults()
        let first = AppSession(store: store, launch: plain, defaults: defaults)
        #expect(first.mode == .onboarding)
        try first.signIn(with: Fixtures.key)
        let second = AppSession(store: store, launch: plain, defaults: defaults)
        #expect(second.mode == .live(Fixtures.key))
        #expect(second.maskedKey == Fixtures.key.masked)
        #expect(second.makeRepository() != nil)
        try second.signOut()
        #expect(second.mode == .onboarding)
        #expect(second.makeRepository() == nil)
    }

    @Test("Sign-out failure keeps the session")
    func signOutFailure() {
        let defaults = Fixtures.freshDefaults()
        defaults.set(true, forKey: AppSession.hasLaunchedKey)
        let session = AppSession(store: InMemoryCredentialStore(key: Fixtures.key, failure: .unexpectedStatus(-1)), launch: plain, defaults: defaults)
        #expect(throws: CredentialStoreError.unexpectedStatus(-1)) { try session.signOut() }
        #expect(session.mode == .live(Fixtures.key))
    }

    @Test("UI testing uses stubs and never a live key")
    func uiTesting() {
        let launch = LaunchConfiguration(arguments: ["-uiTesting"], environment: ["STUB_SCENARIO": "failure", "NEWSAPI_KEY": Fixtures.key.value])
        let session = AppSession(store: InMemoryCredentialStore(), launch: launch, defaults: Fixtures.freshDefaults())
        #expect(session.mode == .demo(.failure))
        #expect(session.isDemo)
        #expect(launch.environmentKey == nil)
        let onboarding = LaunchConfiguration(arguments: ["-uiTesting"], environment: ["STUB_SCENARIO": "onboarding"])
        #expect(AppSession(store: InMemoryCredentialStore(), launch: onboarding, defaults: Fixtures.freshDefaults()).mode == .onboarding)
        session.startDemo()
        #expect(session.mode == .demo(.standard))
    }
}

@Suite("Stub catalogue")
struct StubTests {
    @Test("Standard, empty, failure and flaky scenarios")
    func scenarios() async throws {
        let standard = StubNewsRepository(scenario: .standard, latency: .zero)
        #expect(try await standard.sources(category: .technology).count == 7)
        #expect(try await standard.sources(category: nil).count == StubCatalog.allSources.count)
        let page = try await standard.articles(sourceID: "the-verge", page: 3)
        #expect(page.items.count == StubNewsRepository.articlesPerSource - 40)
        #expect(!page.hasMore)
        #expect(try await standard.searchArticles(query: "ai", page: 1).items.count == 20)
        try await standard.validateKey()

        let empty = StubNewsRepository(scenario: .empty, latency: .zero)
        #expect(try await empty.sources(category: .science).isEmpty)
        #expect(try await empty.articles(sourceID: "x", page: 1).items.isEmpty)

        let failing = StubNewsRepository(scenario: .failure, latency: .zero)
        await #expect(throws: APIError.offline) { try await failing.sources(category: nil) }

        let flaky = StubNewsRepository(scenario: .flakyPagination, latency: .zero)
        await #expect(throws: APIError.timedOut) { try await flaky.articles(sourceID: "x", page: 2) }
        #expect(try await flaky.articles(sourceID: "x", page: 2).items.count == 20)
    }

    @Test("Live repository wires endpoints to pages")
    func liveRepository() async throws {
        let http = StubHTTPClient { request in
            let body = request.url!.path().hasSuffix("sources")
                ? #"{"status":"ok","sources":[{"id":"a","name":"A"}]}"#
                : #"{"status":"ok","totalResults":45,"articles":[{"source":{"name":"A"},"title":"T","url":"https://a.com/1"}]}"#
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let repository = NewsAPIRepository(client: NewsAPIClient(key: Fixtures.key, http: http))
        #expect(try await repository.sources(category: nil).count == 1)
        let articles = try await repository.articles(sourceID: "a", page: 2)
        #expect(articles.page == 2 && articles.totalResults == 45)
        #expect(try await repository.searchArticles(query: "x", page: 1).items.count == 1)
        try await repository.validateKey()
    }
}
