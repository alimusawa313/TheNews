import SwiftUI

struct RootView: View {
    let session: AppSession

    var body: some View {
        ZStack {
            Poster.ink.ignoresSafeArea()
            switch session.mode {
            case .onboarding:
                OnboardingModule.build(session: session)
                    .transition(AnyTransition.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
            case .live, .demo:
                MainFlowView(session: session)
                    .id(session.mode)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.smooth, value: session.mode)
        .measuresPosterLayout()
    }
}

struct MainFlowView: View {
    let session: AppSession
    @State private var navigator = Navigator()
    @State private var repository: (any NewsRepository)?

    var body: some View {
        Group {
            if let repository {
                let factory = ModuleFactory(repository: repository, navigator: navigator, session: session)
                NavigationStack(path: $navigator.path) {
                    factory.makeRoot()
                        .navigationDestination(for: AppRoute.self) { factory.destination(for: $0) }
                }
                .sheet(item: $navigator.sheet) { factory.sheet(for: $0).measuresPosterLayout() }
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            if repository == nil { repository = session.makeRepository() }
        }
    }
}
