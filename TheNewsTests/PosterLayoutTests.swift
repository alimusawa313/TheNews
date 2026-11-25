import CoreGraphics
import Testing
@testable import TheNews

@Suite("Poster layout")
struct PosterLayoutTests {
    @Test("iPhone portrait is compact with no side panel")
    func phonePortrait() {
        let layout = PosterLayout(size: CGSize(width: 402, height: 800))
        #expect(!layout.isRoomy)
        #expect(!layout.isLandscape)
        #expect(!layout.usesSidePanel)
        #expect(layout.typeScale == 1)
    }

    @Test("iPhone landscape gets a side panel but stays compact")
    func phoneLandscape() {
        let layout = PosterLayout(size: CGSize(width: 812, height: 381))
        #expect(layout.isLandscape)
        #expect(layout.usesSidePanel)
        #expect(layout.isShortLandscape)
        #expect(!layout.isRoomy)
    }

    @Test("iPad portrait is roomy without a side panel")
    func padPortrait() {
        let layout = PosterLayout(size: CGSize(width: 834, height: 1150))
        #expect(layout.isRoomy)
        #expect(!layout.usesSidePanel)
        #expect(layout.typeScale > 1)
    }

    @Test("iPad landscape is roomy with a side panel")
    func padLandscape() {
        let layout = PosterLayout(size: CGSize(width: 1194, height: 790))
        #expect(layout.isRoomy)
        #expect(layout.usesSidePanel)
        #expect(!layout.isShortLandscape)
    }

    @Test("A narrow split-view window falls back to the phone layout")
    func narrowSplitView() {
        let layout = PosterLayout(size: CGSize(width: 375, height: 1100))
        #expect(!layout.isRoomy)
        #expect(!layout.usesSidePanel)
    }

    @Test("A tiny landscape window is too narrow for a side panel")
    func tinyLandscape() {
        let layout = PosterLayout(size: CGSize(width: 500, height: 400))
        #expect(layout.isLandscape)
        #expect(!layout.usesSidePanel)
    }

    @Test("Columns fit the width, never below one or above three", arguments: [
        (CGFloat(0), 1), (300, 1), (680, 1), (708, 2), (1100, 3), (4000, 3),
    ])
    func columns(width: CGFloat, expected: Int) {
        #expect(PosterLayout.columns(forWidth: width, minimum: 340) == expected)
    }

    @Test("Side panel width is clamped for phones and iPads")
    func sidePanelWidth() {
        let phone = PosterLayout(size: CGSize(width: 812, height: 381))
        let pad = PosterLayout(size: CGSize(width: 1194, height: 790))
        #expect((250...330).contains(phone.sidePanelWidth(for: 812)))
        #expect((340...460).contains(pad.sidePanelWidth(for: 1194)))
    }

    @Test("Wall posters keep a poster ratio and leave room for neighbours")
    func wallPosterSize() {
        let size = PosterLayout.wallPosterSize(in: CGSize(width: 1194, height: 790), reservedHeight: 170)
        #expect(size.height == 620)
        #expect(size.width == 620 * 0.7)
        let tall = PosterLayout.wallPosterSize(in: CGSize(width: 834, height: 1150), reservedHeight: 170)
        #expect(tall.width <= 834 * 0.74)
    }
}
