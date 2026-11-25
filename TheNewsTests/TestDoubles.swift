import Foundation
import Synchronization
@testable import TheNews

nonisolated final class StubHTTPClient: HTTPClient {
    private let handler: @Sendable (URLRequest) throws -> (Data, URLResponse)
    private let recorded = Mutex<[URLRequest]>([])

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse)) { self.handler = handler }

    convenience init(status: Int, body: String, headers: [String: String] = [:]) {
        self.init { request in
            (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
        }
    }

    convenience init(error: any Error) { self.init { _ in throw error } }

    var requests: [URLRequest] { recorded.withLock { $0 } }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        recorded.withLock { $0.append(request) }
        return try handler(request)
    }
}

nonisolated struct FakeNewsRepository: NewsRepository {
    var sourcesResult: Result<[NewsSource], APIError> = .success([])
    var articlesResult: Result<Page<Article>, APIError> = .success(Fixtures.articlePage(1, count: 0, total: 0))
    var searchResult: Result<Page<Article>, APIError> = .success(Fixtures.articlePage(1, count: 0, total: 0))
    var validation: Result<Void, APIError> = .success(())

    func sources(category: NewsCategory?) async throws(APIError) -> [NewsSource] { try sourcesResult.get() }
    func articles(sourceID: String, page: Int) async throws(APIError) -> Page<Article> { try articlesResult.get() }
    func searchArticles(query: String, page: Int) async throws(APIError) -> Page<Article> { try searchResult.get() }
    func validateKey() async throws(APIError) { try validation.get() }
}

nonisolated final class InMemoryCredentialStore: CredentialStoring {
    private let stored: Mutex<APIKey?>
    private let failure: CredentialStoreError?

    init(key: APIKey? = nil, failure: CredentialStoreError? = nil) {
        stored = Mutex(key)
        self.failure = failure
    }

    var current: APIKey? { stored.withLock { $0 } }
    func load() -> APIKey? { current }
    func save(_ credential: APIKey) throws(CredentialStoreError) {
        if let failure { throw failure }
        stored.withLock { $0 = credential }
    }
    func delete() throws(CredentialStoreError) {
        if let failure { throw failure }
        stored.withLock { $0 = nil }
    }
}

nonisolated enum Fixtures {
    static let key = APIKey(String(repeating: "ab12", count: 8))!

    static func source(_ id: String, category: NewsCategory = .technology) -> NewsSource {
        NewsSource(id: id, name: id.capitalized, summary: "About \(id)", url: URL(string: "https://www.\(id).com"), category: category)
    }

    static func sources(_ count: Int) -> [NewsSource] { (0..<count).map { source(String(format: "src%02d", $0)) } }

    static func article(_ n: Int) -> Article {
        Article(sourceID: "src", sourceName: "Source", author: nil, title: "Story \(n)", summary: nil,
                url: URL(string: "https://example.com/\(n)")!, imageURL: nil, publishedAt: nil)
    }

    static func articlePage(_ page: Int, count: Int = 20, total: Int = 60) -> Page<Article> {
        let start = (page - 1) * 20
        return Page(page: page, items: (start..<start + count).map(article), totalResults: total, pageSize: 20)
    }

    static let defaultsSuite = "TheNewsTests"
    static func freshDefaults() -> UserDefaults {
        let name = "\(defaultsSuite).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        guard clock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}
