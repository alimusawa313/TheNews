import NukeUI
import SwiftUI

/// Capsule call-to-action in inverted poster colours.
struct PosterPill: View {
    let title: String
    let palette: Poster.Palette
    var systemImage = "arrow.right"

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: systemImage).fontWeight(.heavy)
        }
        .font(Poster.label(16, weight: .heavy))
        .foregroundStyle(palette.background)
        .padding(.horizontal, 20)
        .frame(minHeight: 50)
        .background(palette.foreground, in: .capsule)
    }
}

/// Indeterminate bar that sweeps across a track: the endless-scroll loader.
struct SweepBar: View {
    let palette: Poster.Palette
    @State private var phase: CGFloat = -0.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(palette.foreground)
                .frame(width: proxy.size.width * 0.4)
                .offset(x: phase * proxy.size.width)
        }
        .frame(height: 6)
        .background(palette.foreground.opacity(0.2))
        .clipped()
        .onAppear {
            guard !reduceMotion else { phase = 0.3; return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) { phase = 1.0 }
        }
        .accessibilityLabel("Loading more")
    }
}

/// Endlessly scrolling ticker of a word, Swiss-poster style.
struct Marquee: View {
    let text: String
    let color: Color
    var pointsPerSecond: Double = 40
    @State private var unitWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let copies = 12

    /// Driven by a frame clock rather than a one-shot `withAnimation`, so scroll,
    /// paging, and transition transactions can never cancel the loop.
    var body: some View {
        let unit = text.uppercased() + "  ·  "
        // The strip is far wider than the screen, so it lives in an overlay:
        // overlays never change the size of the view they sit on.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .overlay(alignment: .leading) {
                TimelineView(.animation(paused: reduceMotion)) { context in
                    HStack(spacing: 0) {
                        ForEach(0..<Self.copies, id: \.self) { index in
                            Text(unit)
                                .font(Poster.display(22))
                                .foregroundStyle(color)
                                .fixedSize()
                                .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                                    if index == 0 { unitWidth = width }
                                }
                        }
                    }
                    .fixedSize()
                    .offset(x: -Self.shift(at: context.date, unitWidth: unitWidth, speed: pointsPerSecond))
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// Wraps after exactly one unit so the loop has no visible seam.
    static func shift(at date: Date, unitWidth: CGFloat, speed: Double) -> CGFloat {
        guard unitWidth > 0 else { return 0 }
        let travelled = date.timeIntervalSinceReferenceDate * speed
        return CGFloat(travelled.truncatingRemainder(dividingBy: Double(unitWidth)))
    }
}

/// Full-area empty and error states: a giant headline you can poke (it jolts
/// and buzzes), a ticker of the word behind it, and a spinning retry pill.
struct PosterStateView: View {
    let headline: String
    let message: String
    let palette: Poster.Palette
    var retryTitle: String?
    var retry: (() -> Void)?
    @State private var appeared = false
    @State private var pokes = 0
    @State private var retries = 0
    @Environment(\.posterLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Marquee(text: headline.trimmingCharacters(in: .punctuationCharacters), color: palette.foreground.opacity(0.25))
            Button { pokes += 1 } label: {
                Text(headline)
                    .font(Poster.display(76 * layout.typeScale))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .keyframeAnimator(initialValue: 0.0, trigger: pokes) { content, value in
                content.rotationEffect(.degrees(value), anchor: .bottomLeading).offset(x: value * 2)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(-7, duration: 0.12)
                    SpringKeyframe(5, duration: 0.14)
                    SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                }
            }
            .offset(x: appeared ? 0 : -60)
            .opacity(appeared ? 1 : 0)
            .accessibilityLabel(headline)
            Text(message).font(Poster.label(17))
            if let retryTitle, let retry {
                Button {
                    retries += 1
                    retry()
                } label: {
                    HStack(spacing: 8) {
                        Text(retryTitle)
                        Image(systemName: "arrow.clockwise").fontWeight(.heavy)
                            .rotationEffect(.degrees(Double(retries) * 360))
                            .animation(Motion.bouncy, value: retries)
                    }
                    .font(Poster.label(16, weight: .heavy))
                    .foregroundStyle(palette.background)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 50)
                    .background(palette.foreground, in: .capsule)
                }
                .buttonStyle(.poster)
                .accessibilityIdentifier("retry-button")
            }
        }
        .foregroundStyle(palette.foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
        .onAppear { withAnimation(Motion.bouncy) { appeared = true } }
        .sensoryFeedback(.impact(weight: .heavy), trigger: pokes)
        .sensoryFeedback(.warning, trigger: appeared) { _, new in new && retry != nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(retry == nil ? "empty-state" : "error-state")
    }
}

extension PosterStateView {
    init(error: APIError, palette: Poster.Palette, retry: @escaping () -> Void) {
        self.init(headline: error.headline, message: error.message, palette: palette,
                  retryTitle: error.isRetryable ? "Try again" : nil, retry: error.isRetryable ? retry : nil)
    }
}

/// Blinking placeholder rows while the first page loads.
struct SkeletonRows: View {
    let palette: Poster.Palette
    var count = 5
    var columns = 1
    @State private var dim = false

    var body: some View {
        PosterGrid(columns: columns) {
            ForEach(0..<count * max(columns, 1), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle().frame(width: index.isMultiple(of: 2) ? 240 : 190, height: 28)
                    Rectangle().frame(width: 140, height: 12)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(palette.foreground.opacity(0.25)).frame(height: 2) }
            }
        }
        .foregroundStyle(palette.foreground.opacity(dim ? 0.12 : 0.32))
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { dim = true } }
        .accessibilityLabel("Loading")
        .accessibilityIdentifier("skeleton")
    }
}

/// Article photo rendered as a duotone in the category's accent so every
/// image belongs to the poster. Falls back to a typographic block.
struct DuotoneImage: View {
    let url: URL?
    let palette: Poster.Palette
    let fallback: String

    var body: some View {
        Color.clear
            .overlay {
                LazyImage(url: url, transaction: Transaction(animation: Motion.smooth)) { state in
                    if let image = state.image {
                        // True duotone: ink shadows, highlights in the poster colour,
                        // so photos stay readable on every palette.
                        ZStack {
                            Poster.ink
                            palette.duotoneHighlight.mask {
                                image.resizable().scaledToFill().grayscale(1).contrast(1.15).luminanceToAlpha()
                            }
                        }
                        .transition(.opacity)
                    } else {
                        ZStack(alignment: .bottomLeading) {
                            palette.foreground.opacity(state.isLoading ? 0.12 : 0.9)
                            if !state.isLoading {
                                Text(fallback)
                                    .font(Poster.display(40))
                                    .foregroundStyle(palette.background)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.4)
                                    .padding(10)
                            }
                        }
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}
