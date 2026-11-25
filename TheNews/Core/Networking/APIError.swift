import Foundation

/// Every failure the data layer can surface, normalised for the UI.
nonisolated enum APIError: Error, Equatable, Sendable {
    case invalidKey
    case unauthorized
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    /// The free NewsAPI plan stops paging after 100 results. Lists treat this as their end.
    case resultsLimitReached
    case invalidRequest(String?)
    case server(statusCode: Int)
    case unexpectedStatus(Int)
    case offline
    case timedOut
    case decoding(String)
    case cancelled
    case transport(String)
}

nonisolated extension APIError {
    static func map(_ error: any Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError { return map(urlError) }
        if error is DecodingError { return .decoding(String(describing: error)) }
        return .transport(error.localizedDescription)
    }

    static func map(_ urlError: URLError) -> APIError {
        switch urlError.code {
        case .cancelled: .cancelled
        case .timedOut: .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: .offline
        default: .transport(urlError.localizedDescription)
        }
    }

    /// Maps NewsAPI's error body (`{"status":"error","code":…,"message":…}`) and HTTP status.
    static func from(statusCode: Int, code: String?, message: String?, retryAfterHeader: String?) -> APIError {
        switch code {
        case "apiKeyMissing", "apiKeyInvalid", "apiKeyDisabled": return .unauthorized
        case "apiKeyExhausted", "rateLimited": return .rateLimited(retryAfter: retryAfterHeader.flatMap(TimeInterval.init))
        case "maximumResultsReached": return .resultsLimitReached
        case "sourceDoesNotExist": return .notFound
        case "parametersMissing", "parameterInvalid", "sourcesTooMany", "sourcesTooFew": return .invalidRequest(message)
        default: break
        }
        switch statusCode {
        case 401: return .unauthorized
        case 404: return .notFound
        case 426: return .resultsLimitReached
        case 429: return .rateLimited(retryAfter: retryAfterHeader.flatMap(TimeInterval.init))
        case 400: return .invalidRequest(message)
        case 500...599: return .server(statusCode: statusCode)
        default: return .unexpectedStatus(statusCode)
        }
    }

    var isRetryable: Bool {
        switch self {
        case .invalidKey, .unauthorized, .notFound, .invalidRequest, .cancelled, .resultsLimitReached: false
        default: true
        }
    }

    /// Poster-style headline for full-screen error states.
    var headline: String {
        switch self {
        case .offline: "NO SIGNAL."
        case .timedOut: "TOO SLOW."
        case .unauthorized, .invalidKey: "KEY REJECTED."
        case .rateLimited: "SLOW DOWN."
        case .notFound: "NOT FOUND."
        case .server, .unexpectedStatus: "WIRE DOWN."
        case .decoding: "GARBLED."
        default: "SOMETHING BROKE."
        }
    }

    var message: String {
        switch self {
        case .invalidKey: "Paste the 32-character key from your NewsAPI account."
        case .unauthorized: "NewsAPI rejected this key. Check it in Settings."
        case .notFound: "NewsAPI couldn't find what you asked for."
        case .rateLimited(let retryAfter):
            retryAfter.map { "Too many requests. Try again in \(Int($0.rounded(.up))) seconds." }
                ?? "You've hit NewsAPI's request limit. Try again a little later."
        case .resultsLimitReached: "That's as far back as the free NewsAPI plan goes."
        case .invalidRequest(let detail): detail ?? "The request wasn't valid."
        case .server(let status): "NewsAPI is having trouble (\(status)). Try again shortly."
        case .unexpectedStatus(let status): "NewsAPI answered with status \(status)."
        case .offline: "Check your connection and try again."
        case .timedOut: "The request timed out. Try again."
        case .decoding: "NewsAPI sent something we couldn't read."
        case .cancelled: "Cancelled."
        case .transport(let description): description
        }
    }
}
