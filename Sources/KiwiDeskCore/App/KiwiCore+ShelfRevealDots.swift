import AppKit

extension KiwiCore.HidingShelves {
    /// A hidden Space Bar's mark: its Space dots, at most
    /// `ShelfDotWindow.cap` following the current Space with small
    /// end dots where Spaces continue, the current Space's name for
    /// its hovered pill, and its place for VoiceOver. Nil without
    /// Spaces, where the bar hides to a line.
    @MainActor mutating func spaceDots(
        _ items: [SpaceBarOverlay.Item]?,
        key: ShelfRevealer.Key,
        settings: TilingSettings
    ) -> (
        mark: ShelfIndicatorSpec.Mark,
        label: ShelfIndicatorSpec.Label?,
        position: ShelfIndicatorSpec.Position?
    )? {
        let spaces = (items ?? []).filter { $0.space != nil }
        guard !spaces.isEmpty else { return nil }
        let current = spaces.firstIndex(where: \.active)
        // No Space shown here: the row stays where it was.
        let start =
            current.map {
                ShelfDotWindow.start(
                    count: spaces.count,
                    current: $0,
                    previous: dotStarts[key]
                )
            }
            ?? min(
                dotStarts[key] ?? 0,
                max(0, spaces.count - ShelfDotWindow.cap)
            )
        dotStarts[key] = start
        let shown = ShelfDotWindow.shown(count: spaces.count, start: start)
        let dots = shown.range.map { index in
            let ends =
                (index == shown.range.lowerBound && shown.before)
                || (index == shown.range.upperBound - 1 && shown.after)
            return ShelfIndicatorSpec.Dot(
                current: spaces[index].active,
                occupied: spaces[index].windowCount > 0,
                small: ends && !spaces[index].active
            )
        }
        let look = settings.spaceBarLook
        let label = current.map {
            ShelfIndicatorSpec.label(
                spaces[$0].spaceGlyph,
                font: look.shelf.textFont(
                    ofSize: look.identifierFontSize(
                        forContentDepth: ShelfIndicatorSpec.labelDepth
                    )
                )
            )
        }
        return (
            .dots(dots),
            label,
            current.map { .init(index: $0 + 1, count: spaces.count) }
        )
    }
}
