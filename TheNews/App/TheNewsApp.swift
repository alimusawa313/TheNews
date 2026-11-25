import Nuke
import SwiftUI

@main
struct TheNewsApp: App {
    @State private var session: AppSession

    init() {
        ImagePipeline.shared = ImagePipeline(configuration: .withDataCache)
        _session = State(initialValue: AppSession(store: KeychainCredentialStore()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
        }
    }
}
