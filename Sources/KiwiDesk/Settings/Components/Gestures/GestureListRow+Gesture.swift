import KiwiDeskCore
import SwiftUI

extension GestureListRow {
    /// The gesture pop-up (#3281, owner ruling B): a text-only face
    /// with the pop-up's chevrons, the row's icon column carrying the
    /// glyph, over a menu whose items wear their glyphs under
    /// headings. VoiceOver names it and speaks its value, which a
    /// custom label would otherwise drop (gui.md ▸ a name replaces
    /// the announcement).
    var gesturePicker: some View {
        Menu {
            gestureItems
        } label: {
            HStack(spacing: 6) {
                // As wide as the card's widest item, as a pop-up is,
                // so every row's action column starts at one x.
                ZStack(alignment: .leading) {
                    ForEach(offered, id: \.self) {
                        Text(GestureListWords.input($0)).hidden()
                    }
                    Text(GestureListWords.input(key.input))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(GestureListWords.gesture)
        .accessibilityValue(GestureListWords.input(key.input))
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            gestureColumn = $0
        }
    }

    /// The menu's items: one inline picker, so the current gesture
    /// is checked; a group with nothing offered draws no heading.
    private var gestureItems: some View {
        Picker(
            GestureListWords.gesture,
            selection: Binding(
                get: { key.input },
                set: { input in rekeyInput(to: input) }
            )
        ) {
            ForEach(GestureListWords.groups(of: offered), id: \.title) {
                group in
                Section(group.title) {
                    ForEach(group.inputs, id: \.self) { input in
                        Label {
                            Text(GestureListWords.input(input))
                        } icon: {
                            GlyphImage(GestureListWords.symbol(input))
                        }
                        .tag(input)
                    }
                }
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}
