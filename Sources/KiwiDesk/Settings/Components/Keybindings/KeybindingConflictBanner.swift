import KiwiDeskCore
import SwiftUI

/// Dismissible banner warning for keybinding conflicts.
struct KeybindingConflictBanner: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        if let message = model.liveKeybindingBanner {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(SettingsTheme.warningInk)
                Text(message)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.keybindingWarning = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(SettingsTheme.warningInk)
                .iconButtonAffordance(
                    L(
                        "keybinding_conflict.dismiss",
                        "Dismiss conflict warning"
                    )
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(SettingsTheme.warningSurface)
            )
        }
    }
}
