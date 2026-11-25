import SwiftUI

/// Swiss-poster design tokens: one bold palette per category, compressed
/// display type, flat colour, heavy rules.
enum Poster {
    struct Palette: Hashable {
        let background: Color
        let foreground: Color
        let accent: Color

        /// Status bar / navigation bar appearance that reads on this background.
        var scheme: ColorScheme { foreground == Poster.ink ? .light : .dark }

        /// Light end of a photo duotone: the poster colour on light posters,
        /// the bright accent on dark ones. Shadows are always ink.
        var duotoneHighlight: Color { scheme == .light ? background : accent }
    }

    static let ink = Color(hex: 0x111111)
    static let paper = Color(hex: 0xF4F4EF)
    static let signal = Color(hex: 0xFFE600)
    static let orange = Color(hex: 0xFF4F00)

    static func palette(for category: NewsCategory) -> Palette {
        switch category {
        case .general: Palette(background: ink, foreground: paper, accent: orange)
        case .business: Palette(background: orange, foreground: ink, accent: ink)
        case .technology: Palette(background: Color(hex: 0xE9E9E6), foreground: ink, accent: Color(hex: 0x3B2CFF))
        case .science: Palette(background: Color(hex: 0x3B2CFF), foreground: .white, accent: signal)
        case .health: Palette(background: Color(hex: 0xFF9EBB), foreground: ink, accent: ink)
        case .sports: Palette(background: Color(hex: 0x0B7A52), foreground: .white, accent: signal)
        case .entertainment: Palette(background: signal, foreground: ink, accent: orange)
        }
    }

    /// Search lives on black with the signal yellow.
    static let searchPalette = Palette(background: ink, foreground: .white, accent: signal)

    /// Compressed, black-weight display type.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }
}

enum Motion {
    static let snap = Animation.snappy(duration: 0.3)
    static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.62)
    static let smooth = Animation.smooth(duration: 0.4)
}

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Squash-and-settle press feedback.
struct PosterPressStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1, anchor: .leading)
            .animation(configuration.isPressed ? .snappy(duration: 0.12) : Motion.bouncy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PosterPressStyle {
    static var poster: PosterPressStyle { PosterPressStyle() }
}
