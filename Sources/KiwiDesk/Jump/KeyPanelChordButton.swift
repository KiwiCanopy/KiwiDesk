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
    /// Every title and symbol the button may wear: it stands as wide
    /// as the widest and centres the one it shows, so a title change
    /// moves nothing beside it.
    var reserves: [Label] = []
    let action: () -> Void

    struct Label: Hashable {
        let title: String
        var symbol: String? = nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    ForEach(reserves, id: \.self) { reserve in
                        titleRow(reserve).hidden()
                    }
                    titleRow(Label(title: title, symbol: symbol))
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

    private func titleRow(_ label: Label) -> some View {
        HStack(spacing: 4) {
            if let symbol = label.symbol {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(label.title).lineLimit(1)
        }
    }
}
