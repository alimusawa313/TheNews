import SwiftUI

/// Black full-screen search with a giant input and two result tabs.
struct SearchView: View {
    @State private var presenter: SearchPresenter
    @State private var text = ""
    @FocusState private var focused: Bool
    @Namespace private var tabs
    @Environment(\.posterLayout) private var layout

    private let palette = Poster.searchPalette

    init(presenter: SearchPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        PosterScaffold(palette: palette, minimumColumnWidth: 300, showsRule: false) {
            VStack(alignment: .leading, spacing: 14) {
                searchField
                if !layout.isShortLandscape { tabBar }
            }
            .padding(.bottom, 14)
        } content: { columns in
            VStack(alignment: .leading, spacing: 0) {
                // On a phone on its side the keyboard covers the side panel,
                // so the tabs ride on top of the results instead.
                if layout.isShortLandscape, presenter.hasQuery {
                    tabBar.padding(.vertical, 12)
                }
                content(columns: columns)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .foregroundStyle(.white)
        .background(palette.background.ignoresSafeArea())
        .posterNavigation(palette)
        .navigationTitle("Search")
        .task { await presenter.onAppear() }
        .task(id: text) { await presenter.updateQuery(text) }
        .onAppear { focused = true }
        .sensoryFeedback(.selection, trigger: presenter.tab)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-screen")
    }

    private var searchField: some View {
        TextField("", text: $text, prompt: Text("TYPE HERE").foregroundStyle(.white.opacity(0.35)))
            .font(Poster.display(54 * layout.typeScale))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($focused)
            .foregroundStyle(.white)
            .tint(palette.accent)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(.white).frame(height: 3) }
            .accessibilityLabel("Search sources and articles")
            .accessibilityIdentifier("search-field")
    }

    private var tabBar: some View {
        HStack(spacing: 18) {
            ForEach(SearchPresenter.Tab.allCases) { tab in
                let selected = presenter.tab == tab
                Button {
                    withAnimation(Motion.bouncy) { presenter.tab = tab }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(tab.title)
                            .font(Poster.display(layout.isShortLandscape ? 24 : 30))
                            .lineLimit(1)
                            .fixedSize()
                        if presenter.hasQuery {
                            Text(count(for: tab)).font(Poster.label(13, weight: .heavy)).contentTransition(.numericText())
                        }
                    }
                    .foregroundStyle(selected ? palette.accent : .white.opacity(0.5))
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        if selected {
                            Rectangle().fill(palette.accent).frame(height: 3).matchedGeometryEffect(id: "tab", in: tabs)
                        }
                    }
                }
                .buttonStyle(.poster)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("tab-\(tab.rawValue)")
            }
        }
    }

    private func count(for tab: SearchPresenter.Tab) -> String {
        switch tab {
        case .sources: "\(presenter.matchingSources.count)"
        case .articles: presenter.articles.totalResults > 0 ? "\(min(presenter.articles.totalResults, Page<Article>.resultCap))" : ""
        }
    }

    @ViewBuilder
    private func content(columns: Int) -> some View {
        if !presenter.hasQuery {
            suggestions
        } else if presenter.tab == .sources {
            sourceResults(columns: columns)
        } else {
            articleResults(columns: columns)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRY").font(Poster.display(22)).foregroundStyle(.white.opacity(0.5))
            FlowRow(items: SearchPresenter.suggestions) { label, index in
                let swatch = Poster.palette(for: NewsCategory.allCases[(index + 1) % NewsCategory.allCases.count])
                Button { text = label } label: {
                    Text(label.uppercased())
                        .font(Poster.display(22 * layout.typeScale))
                        .foregroundStyle(swatch.foreground)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(swatch.background, in: .capsule)
                }
                .buttonStyle(.poster)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func sourceResults(columns: Int) -> some View {
        switch presenter.allSources {
        case .idle, .loading:
            SkeletonRows(palette: palette, count: 3, columns: columns)
        case .failed(let error):
            PosterStateView(error: error, palette: palette) { Task { await presenter.retry() } }
        case .empty, .loaded:
            if presenter.matchingSources.isEmpty {
                PosterStateView(headline: "NO MATCH.", message: "No source is called “\(presenter.query)”. Try the Articles tab.", palette: palette)
            } else {
                PosterGrid(columns: min(columns, 2)) {
                    ForEach(Array(presenter.matchingSources.enumerated()), id: \.element.id) { index, source in
                        Button { presenter.didSelect(source) } label: {
                            SourceRow(index: index + 1, source: source, palette: palette)
                        }
                        .buttonStyle(.poster)
                        .posterRowEntrance()
                        .accessibilityIdentifier("result-source-\(source.id)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func articleResults(columns: Int) -> some View {
        switch presenter.articles.phase {
        case .idle:
            SkeletonRows(palette: palette, count: 3, columns: columns)
        case .loadingFirstPage where presenter.articles.items.isEmpty:
            SkeletonRows(palette: palette, count: 3, columns: columns)
        case .failedFirstPage(let error):
            PosterStateView(error: error, palette: palette) { Task { await presenter.retry() } }
        case _ where presenter.articles.isEmpty:
            PosterStateView(headline: "NO MATCH.", message: "No recent stories mention “\(presenter.query)”.", palette: palette)
        default:
            VStack(alignment: .leading, spacing: 0) {
                PosterGrid(columns: columns) {
                    ForEach(Array(presenter.articles.items.enumerated()), id: \.element.id) { index, article in
                        Button { presenter.didSelect(article) } label: {
                            if columns > 1 {
                                ArticleCard(index: index + 1, article: article, palette: palette)
                            } else {
                                ArticleRow(index: index + 1, article: article, palette: palette)
                            }
                        }
                        .buttonStyle(.poster)
                        .posterRowEntrance()
                        .onAppear { Task { await presenter.loadMoreIfNeeded(after: article) } }
                        .accessibilityIdentifier("result-article-\(index)")
                    }
                }
                LoadMoreFooter(paginator: presenter.articles, palette: palette, endText: "THAT’S EVERYTHING.") {
                    Task { await presenter.retryNextPage() }
                }
            }
        }
    }
}

/// Wrapping row of chips.
struct FlowRow<Content: View>: View {
    let items: [String]
    @ViewBuilder let content: (String, Int) -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in content(item, index) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            for (index, x) in row.items {
                subviews[index].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }

    private struct Row { var items: [(Int, CGFloat)] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows.removeLast()
            if !row.items.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
            }
            let x = row.items.isEmpty ? 0 : row.width + spacing
            row.items.append((index, x))
            row.width = x + size.width
            row.height = max(row.height, size.height)
            rows.append(row)
        }
        return rows
    }
}
