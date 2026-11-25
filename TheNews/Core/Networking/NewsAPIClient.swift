import Foundation

nonisolated protocol NewsRequesting: Sendable {
    func send<Response: Decodable & Sendable>(_ endpoint: NewsEndpoint, as type: Response.Type) async throws(APIError) -> Response
}

/// Executes NewsAPI requests on the cooperative pool (`@concurrent`) so
/// networking and decoding never block the main thread.
nonisolated struct NewsAPIClient: NewsRequesting {
    static let defaultBaseURL = URL(string: "https://newsapi.org")!

    private let key: APIKey
    private let http: any HTTPClient
    private let baseURL: URL

    init(key: APIKey, http: any HTTPClient = URLSessionHTTPClient(), baseURL: URL = NewsAPIClient.defaultBaseURL) {
        self.key = key
        self.http = http
        self.baseURL = baseURL
    }

    @concurrent
    func send<Response: Decodable & Sendable>(_ endpoint: NewsEndpoint, as type: Response.Type) async throws(APIError) -> Response {
        let request = try endpoint.urlRequest(baseURL: baseURL, key: key)
        let data: Data
        let response: HTTPURLResponse
        do {
            try Task.checkCancellation()
            let (body, raw) = try await http.data(for: request)
            guard let httpResponse = raw as? HTTPURLResponse else { throw APIError.transport("Invalid response.") }
            data = body
            response = httpResponse
        } catch {
            throw APIError.map(error)
        }
        guard (200..<300).contains(response.statusCode) else {
            let body = try? JSONDecoder().decode(NewsAPIErrorBody.self, from: data)
            throw APIError.from(
                statusCode: response.statusCode,
                code: body?.code,
                message: body?.message,
                retryAfterHeader: response.value(forHTTPHeaderField: "Retry-After")
            )
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
