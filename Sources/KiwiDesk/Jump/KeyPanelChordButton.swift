import SwiftUI

/// A key-panel button drawing its chord the way a menu item does;
/// the chord is its hint, never its name. Reached by its chord,
/// never Tab, which steps the panel's sides.
struct KeyPanelChordButton: View {
    let title: String
    let chord: String
    var hint: String? = nil
    /// An SF Symbol drawn before the title — the Settings page the
    /// button opens — decorative, so the name stays the title.
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    if let symbol {
                        Image(systemName: symbol)
                            .imageScale(.small)
                            .accessibilityHidden(true)
                    }
                    Text(title).lineLimit(1)
                }
                Text(verbatim: chord)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .settingsActionButton()
        .controlSize(.small)
        // The field keeps the keys; the chord reaches the button.
        .focusable(false)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? LayoutPickText.chordHint(chord))
    }
}
