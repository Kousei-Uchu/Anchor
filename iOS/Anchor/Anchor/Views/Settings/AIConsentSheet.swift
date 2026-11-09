import SwiftUI

/// The sheet shown before anything is sent to an AI tool (Patch AI1, docs/OPTIONAL_FEATURES.md, the consent
/// sheet). It shows what is sent, to whom, and what happens to it, with Send and Cancel pinned at the bottom so
/// they are never below the fold. Nothing is sent until Send. It shows the whole text and never shortens it, and
/// `scripts/check-ai-gate.mjs` fails if this file starts cutting text with a line limit.
struct AIConsentSheet: View {
    let request: AIAskRequest
    let onDecision: (_ send: Bool, _ dontAskAgain: Bool) -> Void
    @State private var dontAskAgain = false

    var body: some View {
        NavigationStack {
            Form {
                Anchor.SettingsSection(title: "Text to send") {
                    Text(request.text)
                        .font(.system(.body, design: .rounded))
                        .textSelection(.enabled)
                }
                Anchor.SettingsSection(title: "Sent with it") {
                    Text(request.instruction)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Anchor.SettingsSection(title: "Where it goes") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.provider.name)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                        Text(request.provider.whereItRuns)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Anchor.SettingsSection(title: "What happens to it") {
                    Text(request.provider.keeping)
                        .font(.system(.subheadline, design: .rounded))
                }
                if request.provider.offersDontAskAgain {
                    Anchor.SettingsSection(
                        title: nil,
                        footer: "You can turn this off again in Settings, AI tools."
                    ) {
                        Anchor.SettingsToggle(title: "Don't ask again for this", isOn: $dontAskAgain)
                    }
                }
            }
            .anchorSettingsStyle()
            .navigationTitle(request.feature.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("Send") { onDecision(true, dontAskAgain) }
                        .buttonStyle(Anchor.PrimaryButtonStyle())
                    Button("Cancel") { onDecision(false, false) }
                        .font(.system(.subheadline, design: .rounded))
                        .padding(.vertical, 6)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(.bar)
            }
        }
        .presentationDetents([.large])
    }
}

private struct AIAskModifier: ViewModifier {
    @ObservedObject var ask: AIAsk

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { ask.pending },
            set: { newValue in
                if newValue == nil { ask.resolve(false) }
            }
        )) { request in
            AIConsentSheet(request: request) { send, dontAskAgain in
                ask.resolve(send, dontAskAgain: dontAskAgain)
            }
        }
    }
}

extension View {
    /// Shows the consent sheet for this `AIAsk` whenever it is waiting for an answer.
    func aiAsk(_ ask: AIAsk) -> some View {
        modifier(AIAskModifier(ask: ask))
    }
}
