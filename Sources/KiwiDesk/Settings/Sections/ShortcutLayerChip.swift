import SwiftUI

/// One persistent Shortcuts layer chip, a `ChoiceChip`: an
/// unselected chip lifts its rest fill on hover, with no geometry
/// or cursor change.
struct ShortcutLayerChip: View {
    let name: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .choiceChip(
                    selected: selected,
                    hovering: hovering && isEnabled
                )
                .animation(hoverAnimation, value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = isEnabled && $0 }
        .onChange(of: isEnabled) { _, now in
            if !now { hovering = false }
        }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var hoverAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }
}
