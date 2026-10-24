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
        mark: ShelfHandleSpec.Mark,
        label: ShelfHandleSpec.Label?,
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
        let label = current.map {
            ShelfHandleSpec.label(
                spaces[$0].spaceGlyph,
                font: Self.markNameFont(settings)
            )
        }
        return (
            .dots(dots),
            label,
            current.map { .init(index: $0 + 1, count: spaces.count) }
        )
    }

    /// The hovered marks' text size: the Space Bar's own identifier
    /// size, held inside the pill — the Space name's and the App Bar
    /// count's alike, so the two marks read alike (#2567).
    @MainActor static func markTextSize(_ settings: TilingSettings) -> CGFloat
    {
        let look = settings.spaceBarLook
        return min(
            look.identifierFontSize(forDepth: look.shelf.thickness),
            ShelfHandleSpec.labelDepth - 4
        )
    }

    /// The Space mark's name: the shelf's text face.
    @MainActor static func markNameFont(_ settings: TilingSettings) -> NSFont {
        settings.spaceBarLook.shelf.textFont(ofSize: markTextSize(settings))
    }

    /// The App Bar mark's count: the shelf's badge face, as every
    /// bar count takes (bars.md ▸ Bar text takes its face).
    @MainActor static func markCountFont(
        _ settings: TilingSettings
    ) -> NSFont {
        settings.spaceBarLook.shelf.badgeFont(
            ofSize: markTextSize(settings),
            emphasis: .semibold
        )
    }
}
