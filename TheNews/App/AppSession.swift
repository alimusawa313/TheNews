import Foundation
import Observation
import os

/// Parses launch arguments / environment (scheme, CI, UI tests).
nonisolated struct LaunchConfiguration: Sendable {
    static let uiTestingArgument = "-uiTesting"
    static let demoArgument = "-demo"
    static let scenarioKey = "STUB_SCENARIO"
    static let apiKeyKey = "NEWSAPI_KEY"
    static let onboardingScenario = "onboarding"

    let stubScenario: StubNewsRepository.Scenario?
    let environmentKey: APIKey?
    let resetsStoredKey: Bool
    let stubLatency: Duration

    init(arguments: [String] = ProcessInfo.processInfo.arguments,
         environment: [String: String] = ProcessInfo.processInfo.environment) {
        let isUITesting = arguments.contains(Self.uiTestingArgument)
        let isDemo = arguments.contains(Self.demoArgument)
        let rawScenario = environment[Self.scenarioKey]
        let wantsOnboarding = rawScenario == Self.onboardingScenario
        stubScenario = (isUITesting || isDemo) && !wantsOnboarding
            ? (rawScenario.flatMap(StubNewsRepository.Scenario.init(rawValue:)) ?? .standard)
            : nil
        // UI tests never touch the live API, even if a key is in the environment.
        environmentKey = isUITesting ? nil : environment[Self.apiKeyKey].flatMap(APIKey.init)
        resetsStoredKey = isUITesting
        stubLatency = isUITesting ? .milliseconds(250) : .milliseconds(600)
    }
}

/// Owns how the app gets its data: onboarding, live NewsAPI, or demo stubs.
@Observable
final class AppSession {
    enum Mode: Hashable {
        case onboarding
        case live(APIKey)
        case demo(StubNewsRepository.Scenario)
    }

    /// UserDefaults is wiped on uninstall but the Keychain is not, so a
    /// missing flag means a fresh install and any leftover key is dropped.
    static let hasLaunchedKey = "session.hasLaunchedBefore"

    private(set) var mode: Mode
    private let store: any CredentialStoring
    private let stubLatency: Duration
    private let logger = Logger(subsystem: "com.alihaidar.TheNews", category: "Session")

    init(store: any CredentialStoring, launch: LaunchConfiguration = LaunchConfiguration(), defaults: UserDefaults = .standard) {
        self.store = store
        stubLatency = launch.stubLatency
        if launch.resetsStoredKey || !defaults.bool(forKey: Self.hasLaunchedKey) {
            do { try store.delete() } catch {
                logger.error("Failed to clear leftover key: \(String(describing: error), privacy: .public)")
            }
        }
        defaults.set(true, forKey: Self.hasLaunchedKey)
        if let scenario = launch.stubScenario {
            mode = .demo(scenario)
        } else if let key = launch.environmentKey ?? store.load() {
            mode = .live(key)
        } else {
            mode = .onboarding
        }
    }

    var isDemo: Bool {
        if case .demo = mode { return true }
        return false
    }

    var maskedKey: String? {
        if case .live(let key) = mode { return key.masked }
        return nil
    }

    func signIn(with key: APIKey) throws(CredentialStoreError) {
        try store.save(key)
        mode = .live(key)
    }

    func startDemo() {
        mode = .demo(.standard)
    }

    func signOut() throws(CredentialStoreError) {
        do { try store.delete() } catch {
            logger.error("Failed to delete key: \(String(describing: error), privacy: .public)")
            throw error
        }
        mode = .onboarding
    }

    func makeRepository() -> (any NewsRepository)? {
        switch mode {
        case .onboarding: nil
        case .live(let key): Self.liveRepository(for: key)
        case .demo(let scenario): StubNewsRepository(scenario: scenario, latency: stubLatency)
        }
    }

    nonisolated static func liveRepository(for key: APIKey) -> any NewsRepository {
        NewsAPIRepository(client: NewsAPIClient(key: key))
    }
}
