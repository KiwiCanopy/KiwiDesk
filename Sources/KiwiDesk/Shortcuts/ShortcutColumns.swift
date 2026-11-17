import SwiftUI

/// A shortcuts panel section's columns (#3380 ▸ Ruling): the
/// gesture badges right-aligned against a thin divider, then the
/// chords right-aligned in one width, the section's widest. A
/// section with no gesture keeps no badge column. Read by
/// `ShortcutRowView` from the environment; nil draws a row on its
/// own, as the hint panel's branch rows do.
struct ShortcutColumns: Equatable {
    /// Whether any row of the section carries a gesture.
    var badges: Bool
    /// Whether any row of the section carries a chord: the divider
    /// parts the badges from the chords, so it needs both.
    var chords: Bool
    /// The section's widest chord, measured as drawn.
    var chord: CGFloat = 0

    /// The divider's slot, kept on a row without a gesture so the
    /// chords line up.
    static let dividerSlot: CGFloat = 9
    /// The divider's height, a little under the row's text.
    static let dividerLength: CGFloat = 14
}

/// Each chord's drawn width, folded to the section's widest.
struct ShortcutChordWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Measures a section's chords and hands its rows the columns.
struct ShortcutSectionColumns: ViewModifier {
    let badges: Bool
    let chords: Bool
    @State private var chord: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .environment(
                \.shortcutColumns,
                ShortcutColumns(
                    badges: badges,
                    chords: chords,
                    chord: chord
                )
            )
            .onPreferenceChange(ShortcutChordWidthKey.self) { chord = $0 }
    }
}

private struct ShortcutColumnsKey: EnvironmentKey {
    static let defaultValue: ShortcutColumns? = nil
}

extension EnvironmentValues {
    /// The section's columns; nil outside a section.
    var shortcutColumns: ShortcutColumns? {
        get { self[ShortcutColumnsKey.self] }
        set { self[ShortcutColumnsKey.self] = newValue }
    }
}
