import Foundation

/// UI-facing lifecycle of a single (non-paginated) resource.
nonisolated enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(APIError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var error: APIError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}

nonisolated extension LoadState: Equatable where Value: Equatable {}
