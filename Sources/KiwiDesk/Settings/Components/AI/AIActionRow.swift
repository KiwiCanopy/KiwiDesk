import KiwiDeskCore
import SwiftUI

/// One AI page row: a title, an optional `?` and caption on the
/// left, its one button trailing — the shape both the setup and
/// the prompts cards draw (owner ruling 2026-10-17). Below
/// `stacksRows` the button goes under the caption.
struct AIActionRow<Action: View>: View {
    let title: String
    let caption: String?
    var help: String? = nil
    @ViewBuilder let button: Action

    var body: some View {
        SettingsRowShape(labelFills: true) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
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
