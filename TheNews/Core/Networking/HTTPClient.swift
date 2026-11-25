import Foundation

/// Thin transport abstraction so the API client can be tested without the network.
nonisolated protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

nonisolated struct URLSessionHTTPClient: HTTPClient {
    private static let requestTimeout: TimeInterval = 15
    private static let resourceTimeout: TimeInterval = 30

    private let session: URLSession

    init(session: URLSession = URLSessionHTTPClient.makeDefaultSession()) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: configuration)
    }
}
