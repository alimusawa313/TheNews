import SwiftUI

// MARK: - VIPER contract

protocol CategoryWallInteracting {
    func categories() -> [NewsCategory]
}

protocol CategoryWallRouting {
    func showSources(for category: NewsCategory)
    func showSearch()
    func showSettings()
}

// MARK: - Interactor

/// NewsAPI's categories are a fixed list, so no request is needed.
struct CategoryWallInteractor: CategoryWallInteracting {
    func categories() -> [NewsCategory] { NewsCategory.allCases }
}

// MARK: - Router

struct CategoryWallRouter: CategoryWallRouting {
    let navigator: Navigator

    func showSources(for category: NewsCategory) { navigator.push(.sources(category)) }
    func showSearch() { navigator.push(.search) }
    func showSettings() { navigator.present(.settings) }
}

// MARK: - Builder

enum CategoryWallModule {
    static func build(navigator: Navigator, isDemo: Bool) -> CategoryWallView {
        CategoryWallView(presenter: CategoryWallPresenter(
            interactor: CategoryWallInteractor(),
            router: CategoryWallRouter(navigator: navigator),
            isDemo: isDemo
        ))
    }
}
