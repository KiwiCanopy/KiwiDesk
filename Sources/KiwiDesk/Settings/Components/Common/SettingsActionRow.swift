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
    /// The caption is a file path: one selectable monospaced line,
    /// cut in the middle.
    var captionIsPath = false
    var help: String? = nil
    /// What the `?` names for VoiceOver where the drawn title is
    /// shorter than the action it explains; the title otherwise.
    var helpSubject: String? = nil
    @ViewBuilder let button: Action

    var body: some View {
        SettingsRowShape(controlTrails: true) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    // Drawn, not spoken: the button names itself.
                    Text(title)
                        .accessibilityHidden(true)
                    if let help {
                        HelpButton(
                            explanation: help,
                            subject: helpSubject ?? title
                        )
                    }
                }
                if let caption, captionIsPath {
                    Text(caption)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                } else if let caption {
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
