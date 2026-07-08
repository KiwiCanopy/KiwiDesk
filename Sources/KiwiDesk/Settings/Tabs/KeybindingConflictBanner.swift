import SwiftUI

/// A dismissible in-app warning shown when a keybinding
/// conflict was just introduced (recording a clashing combo, or
/// a batch check after Adopt / a raw-Lua save). The persistent
/// per-row ⚠️ + tooltip always reflects live state on its own;
/// this banner is only a transient nudge toward it. Its text
/// derives live (`liveKeybindingBanner`), so it disappears
/// once dismissed — or once the conflicts it names are gone,
/// however they were fixed.
struct KeybindingConflictBanner: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        if let message = model.liveKeybindingBanner {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.keybindingWarning = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.12))
            )
        }
    }
}
