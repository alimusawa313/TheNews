import SwiftUI

/// Assembles VIPER modules for each destination.
struct ModuleFactory {
    let repository: any NewsRepository
    let navigator: Navigator
    let session: AppSession

    func makeRoot() -> some View {
        CategoryWallModule.build(navigator: navigator, isDemo: session.isDemo)
    }

    @ViewBuilder
    func destination(for route: AppRoute) -> some View {
        switch route {
        case .sources(let category):
            SourcesModule.build(category: category, repository: repository, navigator: navigator)
        case .articles(let source, let category):
            ArticlesModule.build(source: source, category: category, repository: repository, navigator: navigator)
        case .article(let article, let category):
            ArticleWebModule.build(article: article, category: category)
        case .search:
            SearchModule.build(repository: repository, navigator: navigator)
        }
    }

    @ViewBuilder
    func sheet(for route: SheetRoute) -> some View {
        switch route {
        case .settings: SettingsView(session: session, onClose: navigator.dismissSheet)
        }
    }
}
