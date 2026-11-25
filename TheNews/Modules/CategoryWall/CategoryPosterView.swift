import SwiftUI

/// One category poster: giant number with parallax, title, marquee and CTA.
/// The same poster is composed three ways for the space it gets.
struct CategoryPoster: View {
    enum Style {
        /// Full-screen phone poster, stacked top to bottom.
        case portrait
        /// Full-screen phone on its side: number left, copy right.
        case landscape
        /// Framed poster on the iPad wall.
        case card
    }

    let category: NewsCategory
    let isCurrent: Bool
    let style: Style
    /// Device safe-area insets; full-screen posters draw edge to edge.
    var insets = EdgeInsets()
    /// Where the poster sits when centred on the wall, for horizontal parallax.
    var restingMinX: CGFloat = 0
    let open: () -> Void

    @State private var stamps = 0
    @State private var taps = 0
    private var palette: Poster.Palette { Poster.palette(for: category) }

    var body: some View {
        composition
            .foregroundStyle(palette.foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
            // Parallax lifts the neighbouring poster's number; keep it inside its own poster.
            .clipped()
            .sensoryFeedback(.impact(weight: .medium), trigger: taps)
            .onChange(of: isCurrent) { _, current in if current { stamps += 1 } }
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var composition: some View {
        switch style {
        case .portrait: portrait
        case .landscape: landscape
        case .card: card
        }
    }

    private var portrait: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 96)
            number
            title(size: category.title.count > 11 ? 66 : 86)
                .padding(.top, 4)
                .padding(.trailing, 34) // keep clear of the section index
            Spacer(minLength: 16)
            footer(blurbSize: 15)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 44)
    }

    private var landscape: some View {
        HStack(alignment: .bottom, spacing: 28) {
            // Fixed share of the width so the copy column can never squeeze it out.
            number
                .containerRelativeFrame(.horizontal, alignment: .bottomLeading) { width, _ in width * 0.38 }
                .frame(maxHeight: .infinity, alignment: .bottomLeading)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                title(size: 76)
                footer(blurbSize: 14)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.leading, 22 + insets.leading)
        .padding(.trailing, 22 + insets.trailing + 34) // clear of the section index
        .padding(.top, insets.top + 64)                 // clear of the header
        .padding(.bottom, max(insets.bottom, 10) + 12)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("THE NEWS / \(category.number)").font(Poster.display(18))
                Spacer()
                Text("NO. \(category.number)").font(Poster.display(18)).opacity(0.5)
            }
            Spacer(minLength: 12)
            number
            title(size: category.title.count > 11 ? 84 : 110)
                .padding(.top, 4)
            Spacer(minLength: 16)
            footer(blurbSize: 17)
        }
        .padding(30)
    }

    private var number: some View {
        Button { taps += 1 } label: {
            Text(category.number)
                .font(Poster.display(300))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.25)
        }
        .buttonStyle(.plain)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: stamps + taps) { content, scale in
            content.scaleEffect(scale, anchor: .bottomLeading)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.12, duration: 0.14)
                SpringKeyframe(0.94, duration: 0.14)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
        }
        .visualEffect { [horizontal = style == .card, restingMinX] content, proxy in
            let frame = proxy.frame(in: .scrollView)
            return content.offset(
                x: horizontal ? -(frame.minX - restingMinX) * 0.3 : 0,
                y: horizontal ? 0 : -frame.minY * 0.35
            )
        }
        .accessibilityLabel("Section \(category.number)")
    }

    private func title(size: CGFloat) -> some View {
        Text(category.title.uppercased())
            .font(Poster.display(size))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    private func footer(blurbSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Marquee(text: category.title, color: palette.foreground.opacity(0.3))
                .padding(.bottom, 10)
            Rectangle().fill(palette.foreground).frame(height: 3)
            HStack(alignment: .bottom, spacing: 14) {
                Text(category.blurb)
                    .font(Poster.label(blurbSize))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: open) { PosterPill(title: "Sources", palette: palette) }
                    .buttonStyle(.poster)
                    .accessibilityIdentifier("open-\(category.rawValue)")
            }
            .padding(.top, 14)
        }
    }
}

/// Round icon button used in poster headers.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var inverted = false
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .symbolEffect(.bounce, value: taps)
                .foregroundStyle(inverted ? Poster.ink : .white)
                .frame(width: 46, height: 46)
                .background(inverted ? Poster.paper : Poster.ink, in: .circle)
        }
        .buttonStyle(.poster)
        .accessibilityLabel(label)
    }
}
