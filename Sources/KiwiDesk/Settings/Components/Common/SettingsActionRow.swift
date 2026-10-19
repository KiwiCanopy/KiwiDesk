import KiwiDeskCore
import SwiftUI

/// A titled action row: a title, an optional `?` and caption on
/// the left, its buttons trailing — the AI page's cards and
/// General ▸ Advanced (owner rulings 2026-10-17, #2439). Below
/// `stacksRows` the buttons go under the caption. Each button
/// names itself for VoiceOver (#812).
struct SettingsActionRow<Action: View>: View {
    let title: String
    let caption: String?
    var help: String? = nil
    @ViewBuilder let button: Action

    var body: some View {
        SettingsRowShape(labelFills: true) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    // Drawn, not spoken: the button names itself.
                    Text(title)
                        .accessibilityHidden(true)
                    if let help {
                        HelpButton(explanation: help, subject: title)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } control: {
            button
        }
    }
}
