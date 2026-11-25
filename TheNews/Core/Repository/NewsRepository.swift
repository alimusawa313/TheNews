import Foundation

/// Data-access boundary used by every VIPER interactor.
nonisolated protocol NewsRepository: Sendable {
    /// All sources, optionally filtered by category. NewsAPI does not paginate these.
    func sources(category: NewsCategory?) async throws(APIError) -> [NewsSource]
    func articles(sourceID: String, page: Int) async throws(APIError) -> Page<Article>
    func searchArticles(query: String, page: Int) async throws(APIError) -> Page<Article>
    /// Succeeds when NewsAPI accepts the configured key.
    func validateKey() async throws(APIError)
}

nonisolated struct NewsAPIRepository: NewsRepository {
    private let client: any NewsRequesting

    init(client: any NewsRequesting) {
        self.client = client
    }

    func sources(category: NewsCategory?) async throws(APIError) -> [NewsSource] {
        try await client.send(.sources(category: category), as: SourcesResponse.self).sources
    }

    func articles(sourceID: String, page: Int) async throws(APIError) -> Page<Article> {
        let response = try await client.send(.articles(sourceID: sourceID, page: page), as: ArticlesResponse.self)
        return Page(page: page, items: response.articles, totalResults: response.totalResults, pageSize: NewsEndpoint.pageSize)
    }

    func searchArticles(query: String, page: Int) async throws(APIError) -> Page<Article> {
        let response = try await client.send(.search(query: query, page: page), as: ArticlesResponse.self)
        return Page(page: page, items: response.articles, totalResults: response.totalResults, pageSize: NewsEndpoint.pageSize)
    }

    func validateKey() async throws(APIError) {
        _ = try await client.send(.sources(category: .general), as: SourcesResponse.self)
    }
}
