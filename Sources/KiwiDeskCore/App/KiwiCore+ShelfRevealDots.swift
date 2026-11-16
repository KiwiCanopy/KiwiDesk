import AppKit

extension KiwiCore.HidingShelves {
    /// A hidden Space Bar's peek: its Space dots, at most
    /// `ShelfDotWindow.cap` following the current Space with small
    /// end dots where Spaces continue, and its place for VoiceOver.
    /// Nil without Spaces, where the bar's glyphs peek instead.
    @MainActor mutating func spaceDots(
        _ items: [SpaceBarOverlay.Item]?,
        key: ShelfRevealer.Key
    ) -> (
        peek: ShelfHandleSpec.Peek,
        position: ShelfHandleSpec.Position?
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
            return ShelfHandleSpec.Dot(
                current: spaces[index].active,
                occupied: spaces[index].windowCount > 0,
                small: ends && !spaces[index].active
            )
        }
        return (
            .dots(dots),
            current.map { .init(index: $0 + 1, count: spaces.count) }
        )
    }
}
