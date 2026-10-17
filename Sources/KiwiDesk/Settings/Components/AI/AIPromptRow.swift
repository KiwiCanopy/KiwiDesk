import KiwiDeskCore
import SwiftUI

/// One ready-made prompt: its title and caption, and a Copy
/// button that never greys — the prompt carries no path (#1685).
struct AIPromptRow: View {
    let key: AIKey
    let control: SettingsControl

    var body: some View {
        AIActionRow(
            title: control.text,
            caption: AIReadyPrompt.caption(for: key) ?? ""
        ) {
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
