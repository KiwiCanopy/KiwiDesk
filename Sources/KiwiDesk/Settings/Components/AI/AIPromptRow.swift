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
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            AICopyButton(title: copyTitle) {
                AIReadyPrompt.text(for: key) ?? ""
            }
            .accessibilityLabel(
                L("ai.prompt.copy.ax", "Copy prompt: %1$@", control.text)
            )
        }
        .searchAnchored(control)
    }

    private var copyTitle: String { L("ai.prompt.copy", "Copy") }

    private var caption: String {
        switch key {
        case .promptSpaces:
            return L(
                "ai.prompt.spaces.caption",
                "How many Spaces, what goes where, and each "
                    + "one\u{2019}s layout."
            )
        case .copySetupPrompt:
            return ""
        }
    }
}
