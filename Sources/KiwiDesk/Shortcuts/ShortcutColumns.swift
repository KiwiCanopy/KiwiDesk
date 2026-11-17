import SwiftUI

/// The shortcuts panel's columns (#3380 ▸ Ruling, amended by
/// #3424): the gesture badges right-aligned against a thin divider,
/// then the chords right-aligned in one width, the panel's widest,
/// so every section's divider sits at one x. A panel with no
/// gesture keeps no badge column. Read by `ShortcutRowView` from
/// the environment; nil draws a row on its own, as the hint panel's
/// branch rows do.
struct ShortcutColumns: Equatable {
    /// Whether any row of the panel carries a gesture.
    var badges: Bool
    /// Whether any row of the panel carries a chord: the divider
    /// parts the badges from the chords, so it needs both.
    var chords: Bool
    /// The panel's widest chord, measured as drawn.
    var chord: CGFloat = 0

    /// The divider's slot, kept on a row without a gesture so the
    /// chords line up.
    static let dividerSlot: CGFloat = 9
    /// The divider's height, a little under the row's text.
    static let dividerLength: CGFloat = 14
}

/// Each chord's drawn width, folded to the panel's widest.
struct ShortcutChordWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Measures the panel's chords and hands every row the columns,
/// once for all its sections (#3424).
struct ShortcutPanelColumns: ViewModifier {
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
    /// The panel's columns; nil outside the panel's sections.
    var shortcutColumns: ShortcutColumns? {
        get { self[ShortcutColumnsKey.self] }
        set { self[ShortcutColumnsKey.self] = newValue }
    }
}
