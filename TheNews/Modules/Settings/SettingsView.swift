import SwiftUI

struct SettingsView: View {
    let session: AppSession
    let onClose: () -> Void
    @State private var errorMessage: String?
    @Environment(\.posterLayout) private var layout
    private let palette = Poster.palette(for: .entertainment)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("SETTINGS").font(Poster.display(64))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.headline.weight(.heavy))
                            .foregroundStyle(palette.background)
                            .frame(width: 46, height: 46)
                            .background(palette.foreground, in: .circle)
                    }
                    .buttonStyle(.poster)
                    .accessibilityLabel("Close settings")
                    .accessibilityIdentifier("settings-close")
                }
                Rectangle().frame(height: 3)
                if layout.isLandscape {
                    HStack(alignment: .top, spacing: 32) {
                        status.frame(maxWidth: .infinity, alignment: .leading)
                        actions.frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    status
                    actions
                }
            }
            .padding(24)
        }
        .foregroundStyle(palette.foreground)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.isDemo ? "DEMO MODE" : "CONNECTED").font(Poster.display(34))
            Text(session.maskedKey.map { "Key \($0)" } ?? "Showing offline sample data. Headlines are labelled samples.")
                .font(Poster.label(16))
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                do {
                    try session.signOut()
                    onClose()
                } catch {
                    errorMessage = "Your key couldn’t be removed from the Keychain. Try again."
                }
            } label: {
                PosterPill(title: session.isDemo ? "Connect a key" : "Change key", palette: palette, systemImage: "key.fill")
            }
            .buttonStyle(.poster)
            if let errorMessage {
                Text(errorMessage).font(Poster.label(15, weight: .heavy))
            }
            Rectangle().frame(height: 3)
            if let site = URL(string: "https://newsapi.org") {
                Link(destination: site) {
                    Label("Powered by NewsAPI.org", systemImage: "arrow.up.right").font(Poster.label(15, weight: .heavy))
                }
                .frame(minHeight: 44)
            }
        }
    }
}
