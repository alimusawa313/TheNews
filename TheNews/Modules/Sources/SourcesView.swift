import SwiftUI

struct SourcesView: View {
    @State private var presenter: SourcesPresenter
    @State private var picked: NewsSource?
    @Environment(\.posterLayout) private var layout

    init(presenter: SourcesPresenter) {
        _presenter = State(initialValue: presenter)
    }

    private var palette: Poster.Palette { Poster.palette(for: presenter.category) }

    var body: some View {
        PosterScaffold(palette: palette, minimumColumnWidth: 340) {
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
        .accessibilityIdentifier("sources-screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(presenter.category.number) / \(presenter.category.title.uppercased())")
                .font(Poster.display(18))
            Text("SOURCES")
                .font(Poster.display(108 * layout.typeScale))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(presenter.category.blurb).font(Poster.label(16)).padding(.bottom, 14)
            if layout.usesSidePanel {
                PanelStamp(number: presenter.category.number, count: presenter.sources.count, noun: "sources", palette: palette)
            }
        }
    }

    @ViewBuilder
    private func content(columns: Int) -> some View {
        switch presenter.paginator.phase {
        case .idle:
            SkeletonRows(palette: palette, columns: columns)
        case .loadingFirstPage where presenter.sources.isEmpty:
            SkeletonRows(palette: palette, columns: columns)
        case .failedFirstPage(let error):
            PosterStateView(error: error, palette: palette) { Task { await presenter.retry() } }
        case _ where presenter.paginator.isEmpty:
            PosterStateView(headline: "NOTHING HERE.", message: "NewsAPI has no sources for \(presenter.category.title) right now.", palette: palette)
        default:
            VStack(alignment: .leading, spacing: 0) {
                sourceGrid(columns: columns)
                LoadMoreFooter(paginator: presenter.paginator, palette: palette, endText: "THAT’S ALL OF THEM.") {
                    Task { await presenter.retryNextPage() }
                }
            }
        }
    }

    private func sourceGrid(columns: Int) -> some View {
            PosterGrid(columns: columns) {
                ForEach(Array(presenter.sources.enumerated()), id: \.element.id) { index, source in
                    Button {
                        picked = source
                        presenter.didSelect(source)
                    } label: {
                        SourceRow(index: index + 1, source: source, palette: palette)
                    }
                    .buttonStyle(.poster)
                    .posterRowEntrance()
                    .onAppear { Task { await presenter.loadMoreIfNeeded(after: source) } }
                    .accessibilityIdentifier("source-\(source.id)")
                }
            }
    }
}

struct SourceRow: View {
    let index: Int
    let source: NewsSource
    let palette: Poster.Palette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", index))
                .font(Poster.display(20))
                .frame(width: 32, alignment: .leading)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name.uppercased())
                    .font(Poster.display(36))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !source.summary.isEmpty {
                    Text(source.summary).font(Poster.label(14, weight: .medium)).lineLimit(2)
                }
                Text(source.domain.uppercased()).font(Poster.label(12, weight: .heavy)).tracking(0.6)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right").font(.headline.weight(.heavy)).padding(.top, 8)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.foreground.opacity(0.3)).frame(height: 2) }
        .accessibilityElement(children: .combine)
    }
}
