import SwiftUI

extension VerticalAlignment {
    private enum ShortcutLine: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            d[VerticalAlignment.center]
        }
    }

    /// The middle of a shortcut row's first line: the recorder's
    /// well, so text under the well grows the row downward and the
    /// title stays put (#3258 ▸ owner ruling).
    static let shortcutLine = VerticalAlignment(ShortcutLine.self)
}

private struct RecorderConflictSlotKey: EnvironmentKey {
    static var defaultValue: Binding<RecorderRejection?>? { nil }
}

extension EnvironmentValues {
    /// Where the recorder below puts its refused chord, set by the
    /// `ShortcutKeyRow` hosting it; nil draws the conflict row in
    /// the recorder's own column.
    var recorderConflictSlot: Binding<RecorderRejection?>? {
        get { self[RecorderConflictSlotKey.self] }
        set { self[RecorderConflictSlotKey.self] = newValue }
    }
}

/// A Shortcuts row that holds a key recorder: its controls on one
/// line aligned on the well, and a refused chord's conflict row as a
/// line of its own under them, across the row (#3258 ▸ owner
/// ruling). The one door for such a row (`ShortcutKeyRowSeamTests`).
struct ShortcutKeyRow<Content: View>: View {
    let spacing: CGFloat?
    let content: Content
    @State private var conflict: RecorderRejection?

    init(
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    #if DEBUG
        /// A row already holding a refused chord, for a test that
        /// cannot open the Sides menu: a tracked menu ends the test
        /// process.
        init(
            seeded conflict: RecorderRejection,
            @ViewBuilder content: () -> Content
        ) {
            self.init(content: content)
            _conflict = State(initialValue: conflict)
        }
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .shortcutLine, spacing: spacing) {
                content
            }
            .environment(\.recorderConflictSlot, $conflict)
            if let conflict {
                RecorderConflictLine(rejection: conflict) {
                    self.conflict = nil
                }
                .padding(.leading, SettingsMetrics.shortcutTextIndent)
            }
        }
    }
}

extension View {
    /// Aligns a multi-line title on its first line's middle, so it
    /// sits beside the well (`VerticalAlignment.shortcutLine`).
    func shortcutLineTitle() -> some View {
        alignmentGuide(.shortcutLine) { $0[VerticalAlignment.center] }
    }
}
