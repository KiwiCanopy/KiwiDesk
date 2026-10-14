import KiwiDeskCore
import SwiftUI

/// One ready-made prompt: its title and caption, and a Copy
/// button that never greys — the prompt carries no path (#1685).
struct AIPromptRow: View {
    let key: AIKey
    let control: SettingsControl

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(control.text)
                Text(AIReadyPrompt.caption(for: key) ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            AICopyButton(
                title: copyTitle,
                spokenName: L(
                    "ai.prompt.copy.ax",
                    "Copy prompt: %1$@",
                    control.text
                )
            ) {
                AIReadyPrompt.text(for: key) ?? ""
            }
        }
        .searchAnchored(control)
    }

    private var copyTitle: String { L("ai.prompt.copy", "Copy") }
}
