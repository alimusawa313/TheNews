import SwiftUI

/// How much room a screen has, derived from the window's safe-area size so it
/// follows rotation, iPad split view and Stage Manager resizing.
nonisolated struct PosterLayout: Equatable, Sendable {
    /// iPad-class space: bigger type, poster carousel, multi-column grids.
    let isRoomy: Bool
    /// Wider than tall.
    let isLandscape: Bool
    /// Title block moves into a fixed side panel next to the scrolling list.
    let usesSidePanel: Bool

    static let phonePortrait = PosterLayout(size: CGSize(width: 393, height: 759))

    private static let roomyMinWidth: CGFloat = 640
    private static let roomyMinHeight: CGFloat = 560
    private static let sidePanelMinWidth: CGFloat = 560

    init(size: CGSize) {
        isLandscape = size.width > size.height
        isRoomy = size.width >= Self.roomyMinWidth && size.height >= Self.roomyMinHeight
        usesSidePanel = isLandscape && size.width >= Self.sidePanelMinWidth
    }

    /// Short landscape window such as an iPhone on its side.
    var isShortLandscape: Bool { usesSidePanel && !isRoomy }

    /// Multiplier for display type.
    var typeScale: CGFloat { isRoomy ? 1.35 : 1 }

    /// Width of the fixed title panel for a given window width.
    func sidePanelWidth(for width: CGFloat) -> CGFloat {
        isRoomy
            ? min(max(width * 0.32, 340), 460)
            : min(max(width * 0.38, 250), 330)
    }

    /// How many columns of at least `minimum` points fit in `width`.
    static func columns(forWidth width: CGFloat, minimum: CGFloat, spacing: CGFloat = 28, maximum: Int = 3) -> Int {
        guard width > 0, minimum > 0 else { return 1 }
        let fitting = Int((width + spacing) / (minimum + spacing))
        return min(max(fitting, 1), maximum)
    }

    /// Size of one poster on the iPad wall, leaving room for header and index.
    static func wallPosterSize(in size: CGSize, reservedHeight: CGFloat = 170) -> CGSize {
        let height = max(size.height - reservedHeight, 200)
        let width = min(height * 0.7, size.width * 0.74)
        return CGSize(width: width, height: height)
    }
}

extension EnvironmentValues {
    @Entry var posterLayout = PosterLayout.phonePortrait
}

extension View {
    /// Measures this view and publishes the matching `PosterLayout` to everything inside it.
    func measuresPosterLayout() -> some View {
        modifier(PosterLayoutReader())
    }
}

private struct PosterLayoutReader: ViewModifier {
    @State private var layout = PosterLayout.phonePortrait

    func body(content: Content) -> some View {
        content
            .environment(\.posterLayout, layout)
            .onGeometryChange(for: PosterLayout.self) { PosterLayout(size: $0.size) } action: { layout = $0 }
    }
}

/// Lazy grid that degrades to a single column list.
struct PosterGrid<Content: View>: View {
    let columns: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 28, alignment: .top), count: max(columns, 1)),
            alignment: .leading,
            spacing: 0,
            content: content
        )
    }
}

/// Frame shared by the list screens.
/// Compact: the title block scrolls away above the list.
/// Side panel (landscape): the title block stays pinned on the left and the
/// list scrolls beside it. Roomy portrait: title on top, list in columns.
struct PosterScaffold<Header: View, Content: View>: View {
    let palette: Poster.Palette
    var minimumColumnWidth: CGFloat = 340
    var showsRule = true
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: (_ columns: Int) -> Content

    @Environment(\.posterLayout) private var layout
    private let gutter: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            if layout.usesSidePanel {
                split(width: proxy.size.width)
            } else {
                stacked(width: proxy.size.width)
            }
        }
    }

    private func stacked(width: CGFloat) -> some View {
        let inset = layout.isRoomy ? gutter * 1.6 : gutter
        let columns = layout.isRoomy
            ? PosterLayout.columns(forWidth: width - inset * 2, minimum: minimumColumnWidth)
            : 1
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header()
                if showsRule { Rectangle().fill(palette.foreground).frame(height: 3) }
                content(columns)
            }
            .padding(.horizontal, inset)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func split(width: CGFloat) -> some View {
        let side = layout.sidePanelWidth(for: width)
        let listWidth = width - side - 3 - gutter * 2
        return HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { header() }
                    .padding(.horizontal, gutter)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            // The pinned panel stays put when the keyboard rises; only the list reflows.
            .ignoresSafeArea(.keyboard)
            .frame(width: side)
            Rectangle().fill(palette.foreground).frame(width: 3).ignoresSafeArea(edges: .bottom)
            ScrollView {
                content(PosterLayout.columns(forWidth: listWidth, minimum: minimumColumnWidth))
                    .padding(.horizontal, gutter)
                    .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }
}
