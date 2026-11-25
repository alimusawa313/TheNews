import Observation
import SwiftUI

// MARK: - VIPER contract

protocol OnboardingInteracting {
    /// Parses and verifies the key against NewsAPI.
    func validate(_ rawKey: String) async throws(APIError) -> APIKey
}

protocol OnboardingRouting {
    func complete(with key: APIKey) throws(CredentialStoreError)
    func startDemo()
}

// MARK: - Interactor

struct OnboardingInteractor: OnboardingInteracting {
    let makeRepository: (APIKey) -> any NewsRepository

    func validate(_ rawKey: String) async throws(APIError) -> APIKey {
        guard let key = APIKey(rawKey) else { throw .invalidKey }
        try await makeRepository(key).validateKey()
        return key
    }
}

// MARK: - Router

struct OnboardingRouter: OnboardingRouting {
    let session: AppSession

    func complete(with key: APIKey) throws(CredentialStoreError) { try session.signIn(with: key) }
    func startDemo() { session.startDemo() }
}

// MARK: - Presenter

@Observable
final class OnboardingPresenter {
    enum Phase: Equatable { case idle, validating, failed(String), succeeded }

    var input = "" {
        didSet { if case .failed = phase { phase = .idle } }
    }
    var isSecure = true
    private(set) var phase: Phase = .idle
    private(set) var failures = 0

    private let interactor: any OnboardingInteracting
    private let router: any OnboardingRouting
    private let successDelay: Duration

    init(interactor: any OnboardingInteracting, router: any OnboardingRouting, successDelay: Duration = .milliseconds(900)) {
        self.interactor = interactor
        self.router = router
        self.successDelay = successDelay
    }

    var canSubmit: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && phase != .validating && phase != .succeeded
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    func connect() async {
        guard canSubmit else { return }
        phase = .validating
        do {
            let key = try await interactor.validate(input)
            phase = .succeeded
            try? await Task.sleep(for: successDelay)
            try router.complete(with: key)
        } catch let error as APIError {
            if error == .cancelled { phase = .idle } else { fail(error.message) }
        } catch {
            fail("We couldn't save your key securely. Please try again.")
        }
    }

    func paste(_ value: String) { input = value.trimmingCharacters(in: .whitespacesAndNewlines) }
    func startDemo() { router.startDemo() }

    private func fail(_ message: String) {
        phase = .failed(message)
        failures += 1
    }
}

// MARK: - Builder

enum OnboardingModule {
    static func build(session: AppSession) -> OnboardingView {
        OnboardingView(presenter: OnboardingPresenter(
            interactor: OnboardingInteractor(makeRepository: AppSession.liveRepository(for:)),
            router: OnboardingRouter(session: session)
        ))
    }
}
