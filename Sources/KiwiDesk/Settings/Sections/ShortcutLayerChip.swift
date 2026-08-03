import SwiftUI

/// One persistent Shortcuts layer chip. Selection is its rest
/// affordance; an unselected chip only strengthens its existing
/// fill on hover, with no geometry or cursor change.
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
                .background(Capsule().fill(fill))
                .animation(hoverAnimation, value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = isEnabled && $0 }
        .onChange(of: isEnabled) { _, now in
            if !now { hovering = false }
        }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var fill: Color {
        if selected {
            return Color.accentColor.opacity(0.25)
        }
        return Color.secondary.opacity(
            hovering && isEnabled ? 0.18 : 0.12
        )
    }

    private var hoverAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }
}
