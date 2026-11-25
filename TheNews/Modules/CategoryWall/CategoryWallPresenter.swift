import Observation
import SwiftUI

@Observable
final class CategoryWallPresenter {
    let categories: [NewsCategory]
    let isDemo: Bool
    var current: NewsCategory.ID?

    private let router: any CategoryWallRouting

    init(interactor: any CategoryWallInteracting, router: any CategoryWallRouting, isDemo: Bool) {
        self.categories = interactor.categories()
        self.router = router
        self.isDemo = isDemo
        self.current = categories.first?.id
    }

    var currentCategory: NewsCategory {
        categories.first { $0.id == current } ?? categories.first ?? .general
    }

    func didSelect(_ category: NewsCategory) { router.showSources(for: category) }
    func didTapSearch() { router.showSearch() }
    func didTapSettings() { router.showSettings() }
}
