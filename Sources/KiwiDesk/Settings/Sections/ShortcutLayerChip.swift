import SwiftUI

/// One persistent Shortcuts layer chip, a `ChoiceChip`: an
/// unselected chip lifts its rest fill on hover, with no geometry
/// or cursor change. A layer's icon leads its name where one is set
/// (#3267): a symbol in the chip's ink, an emoji in full colour.
struct ShortcutLayerChip: View {
    let name: String
    var icon: ShortcutGlyph? = nil
    let selected: Bool
    let action: () -> Void

    /// The leading icon's square, at the chip's callout size.
    static let iconSide: CGFloat = 14

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    ShortcutGlyphView(glyph: icon, side: Self.iconSide)
                }
                Text(name)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .choiceChip(selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
