import SwiftUI

struct OnboardingView: View {
    @State private var presenter: OnboardingPresenter
    @FocusState private var focused: Bool
    @Environment(\.posterLayout) private var layout
    private let palette = Poster.palette(for: .business)

    init(presenter: OnboardingPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        Group {
            if layout.usesSidePanel {
                HStack(spacing: 0) {
                    titleBlock(size: layout.isRoomy ? 240 : 120)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    Rectangle().frame(width: 3).ignoresSafeArea()
                    ScrollView {
                        form.padding(28)
                    }
                    .frame(width: layout.isRoomy ? 520 : 380)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock(size: layout.isRoomy ? 220 : 150)
                            .padding(.top, 30)
                        Rectangle().frame(height: 3)
                        form
                    }
                    .frame(maxWidth: layout.isRoomy ? 620 : .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(Motion.bouncy, value: presenter.phase)
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(palette.foreground)
        .background(palette.background.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sensoryFeedback(.error, trigger: presenter.failures)
        .sensoryFeedback(.success, trigger: presenter.phase) { _, new in new == .succeeded }
    }

    private func titleBlock(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(presenter.phase == .succeeded ? "YOU’RE\nIN." : "THE\nNEWS")
                .font(Poster.display(size))
                .lineSpacing(-size * 0.2)
                .minimumScaleFactor(0.3)
                .contentTransition(.numericText())
                .animation(Motion.bouncy, value: presenter.phase)
            Text("Every desk, every source, set as posters. Add your free NewsAPI key to begin.")
                .font(Poster.label(17))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            keyField
            if let message = presenter.errorMessage {
                Text(message)
                    .font(Poster.label(15, weight: .heavy))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("key-error")
            }
            Button {
                focused = false
                Task { await presenter.connect() }
            } label: {
                HStack {
                    Text(buttonTitle)
                    Spacer()
                    if presenter.phase == .validating {
                        ProgressView().tint(palette.background)
                    } else {
                        Image(systemName: presenter.phase == .succeeded ? "checkmark" : "arrow.right").fontWeight(.heavy)
                    }
                }
                .font(Poster.display(26))
                .foregroundStyle(palette.background)
                .padding(.horizontal, 22)
                .frame(minHeight: 58)
                .background(palette.foreground, in: .capsule)
            }
            .buttonStyle(.poster)
            .disabled(!presenter.canSubmit && presenter.phase != .succeeded)
            .accessibilityIdentifier("connect-button")
            if let register = URL(string: "https://newsapi.org/register") {
                Link(destination: register) {
                    Label("Get a free key at newsapi.org", systemImage: "arrow.up.right").font(Poster.label(15, weight: .heavy))
                }
                .frame(minHeight: 44)
            }
            Button(action: presenter.startDemo) {
                Text("OR EXPLORE THE DEMO →").font(Poster.display(24)).frame(minHeight: 44)
            }
            .buttonStyle(.poster)
            .accessibilityIdentifier("demo-button")
        }
    }

    private var buttonTitle: String {
        switch presenter.phase {
        case .validating: "CHECKING…"
        case .succeeded: "CONNECTED"
        default: "CONNECT"
        }
    }

    private var keyField: some View {
        HStack(spacing: 10) {
            Group {
                if presenter.isSecure {
                    SecureField("", text: $presenter.input, prompt: Text("Paste your API key").foregroundStyle(palette.foreground.opacity(0.5)))
                } else {
                    TextField("", text: $presenter.input, prompt: Text("Paste your API key").foregroundStyle(palette.foreground.opacity(0.5)))
                }
            }
            .font(.system(size: 18, weight: .semibold, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .submitLabel(.go)
            .onSubmit { Task { await presenter.connect() } }
            .accessibilityLabel("NewsAPI key")
            .accessibilityIdentifier("key-field")
            Button { presenter.isSecure.toggle() } label: {
                Image(systemName: presenter.isSecure ? "eye" : "eye.slash")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(presenter.isSecure ? "Show key" : "Hide key")
            PasteButton(payloadType: String.self) { values in presenter.paste(values.first ?? "") }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
                .tint(palette.foreground)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .overlay { Rectangle().stroke(palette.foreground, lineWidth: 3) }
        .keyframeAnimator(initialValue: 0.0, trigger: presenter.failures) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-16, duration: 0.07)
                CubicKeyframe(14, duration: 0.07)
                CubicKeyframe(-8, duration: 0.07)
                SpringKeyframe(0, duration: 0.25)
            }
        }
    }
}
