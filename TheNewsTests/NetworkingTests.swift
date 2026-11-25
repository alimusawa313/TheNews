import Foundation
import Testing
@testable import TheNews

@Suite("NewsAPI client")
struct NewsAPIClientTests {
    private func client(_ http: StubHTTPClient) -> NewsAPIClient { NewsAPIClient(key: Fixtures.key, http: http) }

    @Test("Decodes sources and sends the key in a header, never the URL")
    func sourcesAndHeader() async throws {
        let http = StubHTTPClient(status: 200, body: #"{"status":"ok","sources":[{"id":"bbc-news","name":"BBC News","description":"News","url":"https://www.bbc.co.uk/news","category":"general","language":"en","country":"gb"}]}"#)
        let response = try await client(http).send(.sources(category: .general), as: SourcesResponse.self)
        #expect(response.sources.first?.domain == "bbc.co.uk")
        #expect(response.sources.first?.category == .general)
        let request = try #require(http.requests.first)
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == Fixtures.key.value)
        #expect(request.url?.absoluteString.contains(Fixtures.key.value) == false)
    }

    @Test("Maps NewsAPI error codes", arguments: [
        (401, "apiKeyInvalid", APIError.unauthorized),
        (401, "apiKeyMissing", APIError.unauthorized),
        (429, "rateLimited", APIError.rateLimited(retryAfter: nil)),
        (429, "apiKeyExhausted", APIError.rateLimited(retryAfter: nil)),
        (426, "maximumResultsReached", APIError.resultsLimitReached),
        (404, "sourceDoesNotExist", APIError.notFound),
        (400, "parameterInvalid", APIError.invalidRequest("bad")),
        (500, "unexpectedError", APIError.server(statusCode: 500)),
        (418, "teapot", APIError.unexpectedStatus(418))
    ])
    func errorCodes(status: Int, code: String, expected: APIError) async {
        let http = StubHTTPClient(status: status, body: #"{"status":"error","code":"\#(code)","message":"bad"}"#)
        await #expect(throws: expected) { try await client(http).send(.sources(category: nil), as: SourcesResponse.self) }
    }

    @Test("Falls back to HTTP status when the body is not JSON")
    func statusFallback() async {
        let http = StubHTTPClient(status: 503, body: "<html>")
        await #expect(throws: APIError.server(statusCode: 503)) { try await client(http).send(.sources(category: nil), as: SourcesResponse.self) }
    }

    @Test("Reads Retry-After when rate limited")
    func retryAfter() async {
        let http = StubHTTPClient(status: 429, body: "{}", headers: ["Retry-After": "12"])
        await #expect(throws: APIError.rateLimited(retryAfter: 12)) { try await client(http).send(.sources(category: nil), as: SourcesResponse.self) }
    }

    @Test("Maps transport failures", arguments: [
        (URLError(.notConnectedToInternet), APIError.offline),
        (URLError(.timedOut), APIError.timedOut),
        (URLError(.cancelled), APIError.cancelled)
    ])
    func transport(error: URLError, expected: APIError) async {
        await #expect(throws: expected) { try await client(StubHTTPClient(error: error)).send(.sources(category: nil), as: SourcesResponse.self) }
    }

    @Test("Malformed JSON becomes a decoding error")
    func malformed() async {
        do {
            _ = try await client(StubHTTPClient(status: 200, body: "nope")).send(.sources(category: nil), as: SourcesResponse.self)
            Issue.record("Expected failure")
        } catch {
            guard case .decoding = error else { Issue.record("Got \(error)"); return }
        }
    }
}

@Suite("Endpoints and keys")
struct EndpointTests {
    private func items(_ endpoint: NewsEndpoint) throws -> [String: String] {
        let request = try endpoint.urlRequest(baseURL: NewsAPIClient.defaultBaseURL, key: Fixtures.key)
        let parts = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: parts.map { ($0.name, $0.value ?? "") })
    }

    @Test("Sources filter by category")
    func sources() throws {
        #expect(NewsEndpoint.sources(category: .science).path == "/v2/top-headlines/sources")
        #expect(try items(.sources(category: .science))["category"] == "science")
        #expect(try items(.sources(category: nil)).isEmpty)
    }

    @Test("Articles page newest first from one source")
    func articles() throws {
        let q = try items(.articles(sourceID: "the-verge", page: 3))
        #expect(q["sources"] == "the-verge")
        #expect(q["page"] == "3")
        #expect(q["pageSize"] == "\(NewsEndpoint.pageSize)")
        #expect(q["sortBy"] == "publishedAt")
    }

    @Test("Search encodes '+' and '&' safely")
    func searchEncoding() throws {
        let request = try NewsEndpoint.search(query: "C++ & AI", page: 1).urlRequest(baseURL: NewsAPIClient.defaultBaseURL, key: Fixtures.key)
        #expect(request.url?.query?.contains("q=C%2B%2B%20%26%20AI") == true)
        #expect(try items(.search(query: "C++ & AI", page: 1))["q"] == "C++ & AI")
    }

    @Test("API key parsing", arguments: [
        ("  0123456789abcdef0123456789ABCDEF ", true),
        ("short", false),
        (String(repeating: "a", count: 33), false),
        ("0123456789abcdef0123456789abcde!", false),
        ("", false)
    ])
    func keyParsing(raw: String, valid: Bool) {
        #expect((APIKey(raw) != nil) == valid)
    }

    @Test("Masked key only reveals the last four characters")
    func masked() {
        #expect(Fixtures.key.masked == "••••••••ab12")
    }

    @Test("Every error has poster copy, and retryability is sensible")
    func presentation() {
        let all: [APIError] = [.invalidKey, .unauthorized, .notFound, .rateLimited(retryAfter: 3), .resultsLimitReached, .invalidRequest(nil),
                               .server(statusCode: 500), .unexpectedStatus(1), .offline, .timedOut, .decoding("x"), .cancelled, .transport("t")]
        for error in all { #expect(!error.headline.isEmpty && !error.message.isEmpty) }
        #expect(APIError.offline.isRetryable)
        #expect(!APIError.unauthorized.isRetryable)
        #expect(!APIError.resultsLimitReached.isRetryable)
        #expect(APIError.map(CancellationError()) == .cancelled)
    }
}

@Suite("Model decoding")
struct ModelTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("Articles drop [Removed] placeholders and entries without a valid URL")
    func removedAndInvalid() throws {
        let json = """
        {"status":"ok","totalResults":4,"articles":[
          {"source":{"id":"wired","name":"Wired"},"author":"A","title":"Real story","description":"D","url":"https://wired.com/a","urlToImage":"https://img/x.jpg","publishedAt":"2026-11-20T10:00:00Z"},
          {"source":{"id":null,"name":"[Removed]"},"title":"[Removed]","url":"https://removed.com"},
          {"source":{"id":"x","name":"X"},"title":"No URL"},
          {"source":{"id":null,"name":""},"author":"","title":"","description":" ","url":"https://www.site.org/b","urlToImage":"","publishedAt":"bad"}
        ]}
        """
        let response = try decode(ArticlesResponse.self, json)
        #expect(response.totalResults == 4)
        #expect(response.articles.map(\.title) == ["Real story", "Untitled"])
        let sparse = response.articles[1]
        #expect(sparse.sourceName == "site.org")
        #expect(sparse.author == nil && sparse.summary == nil && sparse.imageURL == nil && sparse.publishedAt == nil)
        #expect(response.articles[0].publishedAt != nil)
    }

    @Test("Sources tolerate missing fields and skip broken entries")
    func sources() throws {
        let response = try decode(SourcesResponse.self, #"{"sources":[{"id":"a","name":"A"},{"name":"no id"},{"id":"b","name":"B","category":"mystery","url":"https://b.com"}]}"#)
        #expect(response.sources.map(\.id) == ["a", "b"])
        #expect(response.sources[0].summary.isEmpty)
        #expect(response.sources[1].category == nil)
        #expect(response.sources[0].domain == "a")
    }

    @Test("Paging respects the free plan's 100-result cap")
    func cap() {
        #expect(Page<Int>(page: 4, items: [1], totalResults: 500, pageSize: 20).hasMore)
        #expect(!Page<Int>(page: 5, items: [1], totalResults: 500, pageSize: 20).hasMore)
        #expect(!Page<Int>(page: 1, items: [], totalResults: 500, pageSize: 20).hasMore)
    }

    @Test("Categories are numbered in poster order")
    func categories() {
        #expect(NewsCategory.allCases.count == 7)
        #expect(NewsCategory.general.number == "01")
        #expect(NewsCategory.entertainment.number == "07")
        #expect(NewsCategory.allCases.allSatisfy { !$0.title.isEmpty && !$0.blurb.isEmpty })
    }

    @Test("Formatters")
    func formatters() {
        #expect(Formatters.domain(of: URL(string: "https://www.theverge.com/x")!) == "theverge.com")
        #expect(Formatters.timestamp("2026-11-20T10:00:00.123Z") != nil)
        #expect(Formatters.timestamp("yesterday") == nil)
        #expect(Formatters.relative(nil) == nil)
        #expect(Formatters.relative(Date()) != nil)
    }
}
