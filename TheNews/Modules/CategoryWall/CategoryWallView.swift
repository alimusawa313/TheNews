import SwiftUI

/// Home. Phone: one full-screen poster per category, paging vertically
/// (split composition when the phone is on its side). iPad: an actual wall,
/// framed posters in a tilting carousel over a backdrop tinted by the current one.
struct CategoryWallView: View {
    @State private var presenter: CategoryWallPresenter
    @State private var safeInsets = EdgeInsets()
    @Environment(\.posterLayout) private var layout

    init(presenter: CategoryWallPresenter) {
        _presenter = State(initialValue: presenter)
    }

    private var currentPalette: Poster.Palette { Poster.palette(for: presenter.currentCategory) }

    var body: some View {
        Group {
            if layout.isRoomy { wall } else { pager }
        }
        .overlay(alignment: .top) { header }
        .sensoryFeedback(.selection, trigger: presenter.current)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .preferredColorScheme(layout.isRoomy ? .dark : currentPalette.scheme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("category-wall")
    }

    // MARK: Phone

    private var pager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(presenter.categories) { category in
                    CategoryPoster(
                        category: category,
                        isCurrent: presenter.current == category.id,
                        style: layout.isShortLandscape ? .landscape : .portrait,
                        insets: safeInsets
                    ) { presenter.didSelect(category) }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(category.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $presenter.current)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .onGeometryChange(for: EdgeInsets.self, of: \.safeAreaInsets) { safeInsets = $0 }
        .overlay(alignment: .trailing) { verticalIndex }
    }

    private var verticalIndex: some View {
        VStack(spacing: 2) {
            ForEach(presenter.categories) { category in
                let isCurrent = presenter.current == category.id
                Button {
                    withAnimation(Motion.smooth) { presenter.current = category.id }
                } label: {
                    Capsule()
                        .fill(isCurrent ? Color.white : Color.white.opacity(0.45))
                        .frame(width: 8, height: isCurrent ? 26 : 8)
                        .frame(width: 32, height: isCurrent ? 34 : 24)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to \(category.title)")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
        .background(Poster.ink.opacity(0.72), in: .capsule)
        .padding(.trailing, 10)
        .animation(Motion.bouncy, value: presenter.current)
    }

    // MARK: iPad

    private static let headerHeight: CGFloat = 76
    private static let indexHeight: CGFloat = 84

    private var wall: some View {
        GeometryReader { proxy in
            let poster = PosterLayout.wallPosterSize(in: proxy.size, reservedHeight: Self.headerHeight + Self.indexHeight + 10)
            let margin = max((proxy.size.width - poster.width) / 2, 0)
            VStack(spacing: 0) {
                Color.clear.frame(height: Self.headerHeight)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 36) {
                        ForEach(presenter.categories) { category in
                            CategoryPoster(
                                category: category,
                                isCurrent: presenter.current == category.id,
                                style: .card,
                                restingMinX: margin
                            ) { presenter.didSelect(category) }
                            .frame(width: poster.width, height: poster.height)
                            // Hairline so the ink poster still reads against the dark wall.
                            .overlay { Rectangle().stroke(Color.white.opacity(0.14), lineWidth: 1) }
                            .shadow(color: .black.opacity(0.5), radius: 28, y: 16)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.86)
                                    .rotation3DEffect(.degrees(phase.value * -16), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                                    .opacity(phase.isIdentity ? 1 : 0.55)
                            }
                            .id(category.id)
                        }
                    }
                    .scrollTargetLayout()
                    .frame(maxHeight: .infinity)
                }
                .contentMargins(.horizontal, margin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $presenter.current, anchor: .center)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                chipIndex
                    .frame(height: Self.indexHeight)
            }
        }
        .background {
            currentPalette.background
                .overlay(Poster.ink.opacity(0.8))
                .ignoresSafeArea()
                .animation(Motion.smooth, value: presenter.current)
        }
    }

    private var chipIndex: some View {
        ViewThatFits(in: .horizontal) {
            chips(showsTitles: true)
            chips(showsTitles: false)
        }
        .padding(.horizontal, 24)
    }

    private func chips(showsTitles: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(presenter.categories) { category in
                let isCurrent = presenter.current == category.id
                let palette = Poster.palette(for: category)
                Button {
                    withAnimation(Motion.smooth) { presenter.current = category.id }
                } label: {
                    HStack(spacing: 6) {
                        Text(category.number)
                        if showsTitles { Text(category.title.uppercased()) }
                    }
                    .font(Poster.display(20))
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? palette.foreground : Color.white.opacity(0.75))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(isCurrent ? palette.background : Color.white.opacity(0.1), in: .capsule)
                    .overlay { Capsule().stroke(Color.white.opacity(isCurrent ? 0.9 : 0), lineWidth: 2) }
                    .fixedSize()
                }
                .buttonStyle(.poster)
                .accessibilityLabel("Go to \(category.title)")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
        .animation(Motion.bouncy, value: presenter.current)
    }

    // MARK: Shared

    private var header: some View {
        let inverted = layout.isRoomy
        return HStack(spacing: 8) {
            Text("THE NEWS")
                .font(Poster.display(20))
                .foregroundStyle(inverted ? Poster.ink : .white)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(inverted ? Poster.paper : Poster.ink, in: .capsule)
            if presenter.isDemo {
                Text("DEMO")
                    .font(Poster.display(16))
                    .foregroundStyle(Poster.ink)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Poster.signal, in: .capsule)
                    .accessibilityLabel("Demo data")
            }
            Spacer()
            CircleIconButton(systemImage: "magnifyingglass", label: "Search sources and articles", inverted: inverted, action: presenter.didTapSearch)
                .accessibilityIdentifier("search-button")
            CircleIconButton(systemImage: "gearshape.fill", label: "Settings", inverted: inverted, action: presenter.didTapSettings)
                .accessibilityIdentifier("settings-button")
        }
        .padding(.horizontal, layout.isRoomy ? 28 : 18)
        .padding(.top, 6)
    }
}
