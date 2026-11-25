import SwiftUI

struct ArticlesView: View {
    @State private var presenter: ArticlesPresenter
    @State private var picked: Article?
    @Environment(\.posterLayout) private var layout

    init(presenter: ArticlesPresenter) {
        _presenter = State(initialValue: presenter)
    }

    private var palette: Poster.Palette { Poster.palette(for: presenter.category) }

    var body: some View {
        PosterScaffold(palette: palette, minimumColumnWidth: 280) {
            header
        } content: { columns in
            content(columns: columns)
        }
        .refreshable { await presenter.refresh() }
        .foregroundStyle(palette.foreground)
        .background(palette.background.ignoresSafeArea())
        .posterNavigation(palette)
        .posterToast($presenter.refreshError, palette: palette)
        .sensoryFeedback(.selection, trigger: picked)
        .task { await presenter.onAppear() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("articles-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(presenter.source.domain.uppercased()).font(Poster.display(18))
            Text(presenter.source.name.uppercased())
                .font(Poster.display((presenter.source.name.count > 14 ? 58 : 84) * layout.typeScale))
                .lineLimit(layout.usesSidePanel ? 4 : 2)
                .minimumScaleFactor(0.5)
            Text("Latest stories").font(Poster.label(16)).padding(.bottom, 14)
            if layout.usesSidePanel {
                PanelStamp(number: presenter.category.number, count: presenter.articles.count, noun: "stories", palette: palette)
            }
        }
    }

    @ViewBuilder
    private func content(columns: Int) -> some View {
        switch presenter.paginator.phase {
        case .idle:
            SkeletonRows(palette: palette, columns: columns)
        case .loadingFirstPage where presenter.articles.isEmpty:
            SkeletonRows(palette: palette, columns: columns)
        case .failedFirstPage(let error):
            PosterStateView(error: error, palette: palette) { Task { await presenter.retry() } }
        case _ where presenter.paginator.isEmpty:
            PosterStateView(headline: "NO STORIES.", message: "\(presenter.source.name) hasn’t published anything NewsAPI can show right now.", palette: palette)
        default:
            VStack(alignment: .leading, spacing: 0) {
                if let lead = presenter.articles.first {
                    tappable(lead, index: 0) {
                        LeadArticle(article: lead, palette: palette, isWide: columns > 1)
                    }
                }
                PosterGrid(columns: columns) {
                    ForEach(Array(presenter.articles.enumerated()).dropFirst(), id: \.element.id) { index, article in
                        tappable(article, index: index) {
                            if columns > 1 {
                                ArticleCard(index: index + 1, article: article, palette: palette)
                            } else {
                                ArticleRow(index: index + 1, article: article, palette: palette)
                            }
                        }
                    }
                }
                LoadMoreFooter(paginator: presenter.paginator, palette: palette, endText: "END OF THE COLUMN.") {
                    Task { await presenter.retryNextPage() }
                }
            }
        }
    }

    private func tappable<Label: View>(_ article: Article, index: Int, @ViewBuilder label: () -> Label) -> some View {
        Button {
            picked = article
            presenter.didSelect(article)
        } label: {
            label()
        }
        .buttonStyle(.poster)
        .posterRowEntrance()
        .onAppear { Task { await presenter.loadMoreIfNeeded(after: article) } }
        .accessibilityIdentifier("article-\(index)")
    }
}

/// First story, set big. Stacked on phones, image beside the headline when wide.
private struct LeadArticle: View {
    let article: Article
    let palette: Poster.Palette
    let isWide: Bool
    @Environment(\.posterLayout) private var layout

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 28) {
                    image.frame(height: 380).frame(maxWidth: .infinity)
                    copy(titleSize: 56).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    image.frame(height: layout.isShortLandscape ? 180 : 220)
                    copy(titleSize: 38)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.foreground).frame(height: 3) }
        .accessibilityElement(children: .combine)
    }

    private var image: some View {
        DuotoneImage(url: article.imageURL, palette: palette, fallback: article.sourceName.uppercased())
            .overlay(alignment: .topLeading) {
                Text("LEAD")
                    .font(Poster.display(16))
                    .foregroundStyle(palette.background)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(palette.foreground)
            }
    }

    private func copy(titleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(article.title.uppercased())
                .font(Poster.display(titleSize))
                .lineLimit(isWide ? 6 : 4)
                .minimumScaleFactor(0.6)
            if let summary = article.summary {
                Text(summary).font(Poster.label(isWide ? 17 : 15, weight: .medium)).lineLimit(isWide ? 5 : 3)
            }
            ArticleMeta(article: article)
        }
    }
}

/// Phone list row: headline left, small duotone right.
struct ArticleRow: View {
    let index: Int
    let article: Article
    let palette: Poster.Palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: "%02d", index)).font(Poster.display(20))
                Text(article.title).font(Poster.label(18, weight: .heavy)).lineLimit(3)
                ArticleMeta(article: article)
            }
            Spacer(minLength: 0)
            DuotoneImage(url: article.imageURL, palette: palette, fallback: String(article.sourceName.prefix(2)).uppercased())
                .frame(width: 86, height: 86)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.foreground.opacity(0.3)).frame(height: 2) }
        .accessibilityElement(children: .combine)
    }
}

/// Grid card for wide layouts: duotone on top, numbered headline below.
struct ArticleCard: View {
    let index: Int
    let article: Article
    let palette: Poster.Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DuotoneImage(url: article.imageURL, palette: palette, fallback: article.sourceName.uppercased())
                .aspectRatio(3 / 2, contentMode: .fit)
            Text(String(format: "%02d", index)).font(Poster.display(22))
            Text(article.title).font(Poster.label(19, weight: .heavy)).lineLimit(4)
            if let summary = article.summary {
                Text(summary).font(Poster.label(14, weight: .medium)).lineLimit(3).opacity(0.85)
            }
            ArticleMeta(article: article)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.foreground.opacity(0.3)).frame(height: 2) }
        .accessibilityElement(children: .combine)
    }
}

struct ArticleMeta: View {
    let article: Article

    var body: some View {
        Text([article.sourceName, Formatters.relative(article.publishedAt), article.author].compactMap(\.self).joined(separator: " · ").uppercased())
            .font(Poster.label(11, weight: .heavy))
            .tracking(0.5)
            .lineLimit(1)
    }
}
