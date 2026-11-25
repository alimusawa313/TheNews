import SwiftUI

extension View {
    /// Transparent navigation bar tinted for the poster underneath.
    func posterNavigation(_ palette: Poster.Palette) -> some View {
        self
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbarColorScheme(palette.scheme, for: .navigationBar)
            .tint(palette.foreground)
            .navigationBarTitleDisplayMode(.inline)
    }

    /// Rows drift in from the left as they scroll into view.
    func posterRowEntrance() -> some View {
        scrollTransition(.animated(Motion.bouncy)) { content, phase in
            content
                .offset(x: phase.isIdentity ? 0 : -36)
                .opacity(phase.isIdentity ? 1 : 0.35)
        }
    }

    /// Slide-down banner for a failed refresh while content stays visible.
    func posterToast(_ error: Binding<APIError?>, palette: Poster.Palette) -> some View {
        overlay(alignment: .top) {
            if let value = error.wrappedValue {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(value.message).font(Poster.label(14)).lineLimit(2)
                }
                .foregroundStyle(palette.background)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.foreground)
                .frame(maxWidth: 560)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: value) {
                    try? await Task.sleep(for: .seconds(3.5))
                    withAnimation(Motion.bouncy) { error.wrappedValue = nil }
                }
                .onTapGesture { withAnimation(Motion.bouncy) { error.wrappedValue = nil } }
                .accessibilityIdentifier("error-toast")
            }
        }
        .animation(Motion.bouncy, value: error.wrappedValue)
    }
}

/// Footer under endlessly scrolling lists.
struct LoadMoreFooter<Item: Identifiable & Sendable>: View where Item.ID: Sendable {
    let paginator: Paginator<Item>
    let palette: Poster.Palette
    let endText: String
    let retry: () -> Void

    var body: some View {
        Group {
            switch paginator.phase {
            case .loadingNextPage:
                SweepBar(palette: palette).padding(.vertical, 26).accessibilityIdentifier("load-more")
            case .failedNextPage(let error):
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.headline).font(Poster.display(30))
                        Text(error.message).font(Poster.label(13)).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Button(action: retry) {
                        Image(systemName: "arrow.clockwise").font(.headline.weight(.heavy))
                            .foregroundStyle(palette.background)
                            .frame(width: 48, height: 48)
                            .background(palette.foreground, in: .circle)
                    }
                    .buttonStyle(.poster)
                    .accessibilityLabel("Retry loading more")
                    .accessibilityIdentifier("load-more-retry")
                }
                .padding(.vertical, 22)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("load-more-error")
            case .loaded where paginator.hasReachedEnd:
                Text(endText).font(Poster.display(30)).padding(.vertical, 26).accessibilityIdentifier("end-of-list")
            case .loaded where paginator.hasMore && !paginator.items.isEmpty:
                SweepBar(palette: palette).padding(.vertical, 26)
            default:
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(palette.foreground)
        .animation(Motion.snap, value: paginator.phase)
    }
}

/// Foot of a landscape side panel: a ghosted section number over a live count
/// of what has loaded so far, so the pinned panel keeps reporting progress.
struct PanelStamp: View {
    let number: String
    let count: Int
    let noun: String
    let palette: Poster.Palette
    @Environment(\.posterLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(number)
                .font(Poster.display(layout.isRoomy ? 170 : 84))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
            Text("\(count) \(noun.uppercased()) LOADED")
                .font(Poster.label(12, weight: .heavy))
                .tracking(0.6)
                .contentTransition(.numericText())
                .animation(Motion.snap, value: count)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }
}
