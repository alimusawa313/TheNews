import Observation
import SwiftUI
import WebKit

// MARK: - VIPER contract
// The web view is a leaf screen: it has no data interactor (the page comes
// from WebKit) and no outgoing navigation, so it needs no router.

@Observable
final class ArticleWebPresenter {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(APIError)
    }

    let article: Article
    let category: NewsCategory
    let page = WebPage()
    private(set) var phase: Phase = .loading
    private(set) var hasCommitted = false

    init(article: Article, category: NewsCategory) {
        self.article = article
        self.category = category
    }

    var domain: String { Formatters.domain(of: article.url) }
    var canGoBack: Bool { !page.backForwardList.backList.isEmpty }

    func load() async {
        await run(page.load(URLRequest(url: article.url)))
    }

    func reload() async {
        await run(page.reload())
    }

    func goBack() async {
        guard let item = page.backForwardList.backList.last else { return }
        await run(page.load(item))
    }

    private func run(_ navigation: some AsyncSequence<WebPage.NavigationEvent, any Error>) async {
        phase = .loading
        do {
            for try await event in navigation {
                if event == .committed { hasCommitted = true }
                if event == .finished { phase = .loaded }
            }
            if phase == .loading { phase = .loaded }
        } catch {
            let mapped = APIError.map(error)
            phase = mapped == .cancelled ? .loaded : .failed(mapped)
        }
    }
}

enum ArticleWebModule {
    static func build(article: Article, category: NewsCategory) -> ArticleWebView {
        ArticleWebView(presenter: ArticleWebPresenter(article: article, category: category))
    }
}

struct ArticleWebView: View {
    @State private var presenter: ArticleWebPresenter
    @Environment(\.openURL) private var openURL
    @Environment(\.posterLayout) private var layout

    init(presenter: ArticleWebPresenter) {
        _presenter = State(initialValue: presenter)
    }

    private var palette: Poster.Palette { Poster.palette(for: presenter.category) }

    var body: some View {
        // Phone on its side: every vertical point goes to the page and the
        // controls move to a rail along the trailing edge. Only the container
        // layout swaps; the reader keeps its identity, because a WebPage may
        // back exactly one WebView and WebKit traps if a second is created.
        let rail = layout.isShortLandscape
        let container = rail ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        container {
            reader
            if rail {
                Rectangle().fill(palette.foreground).frame(width: 3).ignoresSafeArea(edges: .bottom)
            }
            controls(axis: rail ? .vertical : .horizontal)
        }
        .background(palette.background.ignoresSafeArea())
        .posterNavigation(palette)
        .navigationTitle(presenter.domain)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: presenter.article.url) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .task { await presenter.load() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("article-web")
    }

    private var reader: some View {
        VStack(spacing: 0) {
            progress
            ZStack {
                WebView(presenter.page)
                    .accessibilityIdentifier("web-view")
                if !presenter.hasCommitted, presenter.phase == .loading {
                    titleCard.transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if case .failed(let error) = presenter.phase {
                    ScrollView {
                        VStack(alignment: .leading) {
                            PosterStateView(error: error, palette: palette) { Task { await presenter.reload() } }
                            Button { openURL(presenter.article.url) } label: {
                                PosterPill(title: "Open in Safari", palette: palette, systemImage: "safari")
                            }
                            .buttonStyle(.poster)
                        }
                        .frame(maxWidth: 720, alignment: .leading)
                        .padding(22)
                    }
                    .background(palette.background)
                    .foregroundStyle(palette.foreground)
                    .transition(.opacity)
                }
            }
            .animation(Motion.smooth, value: presenter.hasCommitted)
            .animation(Motion.smooth, value: presenter.phase)
        }
    }

    private var progress: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(palette.foreground)
                .frame(width: proxy.size.width * (presenter.phase == .loading ? max(0.06, presenter.page.estimatedProgress) : 1))
                .animation(Motion.smooth, value: presenter.page.estimatedProgress)
        }
        .frame(height: 5)
        .opacity(presenter.phase == .loading ? 1 : 0)
        .animation(Motion.smooth, value: presenter.phase)
    }

    /// Poster card shown until the page commits, so the wait feels designed.
    private var titleCard: some View {
        Group {
            if layout.isLandscape {
                HStack(alignment: .top, spacing: 32) {
                    cardHeadline(size: 46 * layout.typeScale, lines: 4)
                    VStack(alignment: .leading, spacing: 12) {
                        ArticleMeta(article: presenter.article)
                        if let summary = presenter.article.summary {
                            Text(summary).font(Poster.label(15, weight: .medium)).lineLimit(5)
                        }
                        Spacer()
                        SweepBar(palette: palette)
                    }
                    .frame(width: layout.isRoomy ? 320 : 220)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    cardHeadline(size: 46 * layout.typeScale, lines: 6)
                    ArticleMeta(article: presenter.article)
                    Spacer()
                    SweepBar(palette: palette)
                }
            }
        }
        .foregroundStyle(palette.foreground)
        .padding(layout.isRoomy ? 40 : 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.background)
        .accessibilityIdentifier("web-title-card")
    }

    private func cardHeadline(size: CGFloat, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(presenter.domain.uppercased()).font(Poster.display(18))
            Text(presenter.article.title.uppercased())
                .font(Poster.display(size))
                .lineLimit(lines)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Back, reload and Safari. A bottom bar (centred and capped on iPad so the
    /// buttons stay within thumb reach) or a trailing rail in phone landscape.
    private func controls(axis: Axis) -> some View {
        let layoutBox = axis == .horizontal ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        return layoutBox {
            barButton("chevron.left", label: "Back", disabled: !presenter.canGoBack) { Task { await presenter.goBack() } }
            Spacer()
            barButton("arrow.clockwise", label: "Reload", disabled: false) { Task { await presenter.reload() } }
            Spacer()
            barButton("safari", label: "Open in Safari", disabled: false) { openURL(presenter.article.url) }
        }
        .frame(maxWidth: axis == .horizontal ? 480 : nil, maxHeight: axis == .vertical ? 260 : nil)
        .padding(axis == .horizontal ? .horizontal : .vertical, 32)
        .padding(axis == .horizontal ? .vertical : .horizontal, 8)
        .frame(maxWidth: axis == .horizontal ? .infinity : nil, maxHeight: axis == .vertical ? .infinity : nil)
        .foregroundStyle(palette.foreground)
        .background(palette.background)
    }

    private func barButton(_ symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3.weight(.bold)).frame(width: 48, height: 44)
        }
        .buttonStyle(.poster)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
    }
}
