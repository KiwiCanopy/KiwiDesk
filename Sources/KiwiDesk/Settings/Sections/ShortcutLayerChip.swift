import SwiftUI

/// One persistent Shortcuts layer chip, a `ChoiceChip`: an
/// unselected chip lifts its rest fill on hover, with no geometry
/// or cursor change.
struct ShortcutLayerChip: View {
    let name: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .choiceChip(selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
