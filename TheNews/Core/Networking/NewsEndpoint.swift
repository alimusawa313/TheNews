import Foundation

/// A NewsAPI v2 endpoint, independent of credentials and transport.
nonisolated struct NewsEndpoint: Equatable, Sendable {
    static let pageSize = 20

    let path: String
    let queryItems: [URLQueryItem]

    /// `/v2/top-headlines/sources`, which NewsAPI does not paginate.
    static func sources(category: NewsCategory?) -> NewsEndpoint {
        NewsEndpoint(path: "/v2/top-headlines/sources", queryItems: category.map { [URLQueryItem(name: "category", value: $0.rawValue)] } ?? [])
    }

    /// Newest articles from one source, paginated.
    static func articles(sourceID: String, page: Int) -> NewsEndpoint {
        NewsEndpoint(path: "/v2/everything", queryItems: [
            URLQueryItem(name: "sources", value: sourceID),
            URLQueryItem(name: "sortBy", value: "publishedAt"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ])
    }

    /// Full-text article search, paginated.
    static func search(query: String, page: Int) -> NewsEndpoint {
        NewsEndpoint(path: "/v2/everything", queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "searchIn", value: "title,description"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "sortBy", value: "publishedAt"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ])
    }

    func urlRequest(baseURL: URL, key: APIKey) throws(APIError) -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw .invalidRequest(nil)
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        // URLComponents leaves "+" unescaped, which servers read as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw .invalidRequest(nil) }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The key travels in a header so it never appears in URLs or logs.
        request.setValue(key.value, forHTTPHeaderField: "X-Api-Key")
        return request
    }
}
