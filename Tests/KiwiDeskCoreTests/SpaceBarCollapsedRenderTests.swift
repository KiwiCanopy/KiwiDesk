import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A collapsed Space item as the live bar draws it (#1683): the
/// render measures the item it is handed rather than deciding a
/// collapse of its own, so its lengths are the plan's
/// `itemLengths`; the count reads as a whole count; Minimal still
/// announces the windows; an empty identifier takes the empty
/// ink. Driven through `SpaceBarManager.sync`.
@Suite("Space bar collapsed render", .serialized)
@MainActor
struct SpaceBarCollapsedRenderTests {
    private func app(_ name: String, count: Int = 1)
        -> SpaceBarItemView.App
    {
        SpaceBarItemView.App(
            name: name,
            icon: nil,
            glyph: "a",
            focused: false,
            count: count,
            sticky: true,
            floating: true
        )
    }

    /// Space 1 shown; Space 2 holds three windows, Space 3 none.
    private func items(
        _ content: SpaceBarStyle.InactiveContent
    ) -> [SpaceBarOverlay.Item] {
        let apps: [[SpaceBarItemView.App]] = [
            [app("Notes")], [app("Mail", count: 2), app("Web")], [],
        ]
        return apps.enumerated().map { index, apps in
            SpaceBarOverlay.Item(
                space: SpaceID("\(index + 1)"),
                spaceGlyph: .text("\(index + 1)", tinted: true),
                apps: apps,
                active: index == 0,
                overflow: 0,
                focusInOverflow: false
            ).collapsed(to: content)
        }
    }

    private func render(
        _ content: SpaceBarStyle.InactiveContent
    ) throws -> (SpaceBarOverlay, [SpaceBarOverlay.Item]) {
        LiquidGlassGate.override = { false }
        let items = items(content)
        var bar = paintedSpaceBar(front: nil)
        bar = SpaceBarManager.Bar(
            display: bar.display,
            items: items,
            frontApp: nil,
            frontWindow: nil,
            strip: bar.strip,
            style: bar.style,
            stateMarkColors: bar.stateMarkColors
        )
        let manager = SpaceBarManager()
        manager.sync([bar])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        return (overlay, items)
    }

    @Test(
        "The render draws the lengths the plan measures",
        arguments: SpaceBarStyle.InactiveContent.allCases
    )
    func renderedLengthsAreThePlans(
        content: SpaceBarStyle.InactiveContent
    ) throws {
        let (overlay, items) = try render(content)
        let depth = barTitleStrip.height
        let planned = SpaceBarOverlay.itemLengths(
            items,
            depth: depth,
            look: overlay.lastShown?.style ?? SpaceBarLook()
        )
        let drawn = overlay.itemViews.prefix(items.count)
            .map(\.frame.width)
        #expect(drawn == planned)
        // Collapsing shortens the run it collapses.
        if content != .apps {
            let full = SpaceBarOverlay.itemLengths(
                self.items(.apps),
                depth: depth,
                look: overlay.lastShown?.style ?? SpaceBarLook()
            )
            #expect(planned[1] < full[1])
            #expect(planned[0] == full[0])
        }
    }

    @Test("Window count draws the whole count, unprefixed")
    func countReadsWhole() throws {
        let (overlay, _) = try render(.count)
        let other = overlay.itemViews[1]
        #expect(!other.overflowBadge.isHidden)
        #expect(other.overflowBadge.stringValue == "3")
        // The state badges go with the glyphs.
        #expect(other.stickyBadgeViews.isEmpty)
        #expect(other.floatingBadgeViews.isEmpty)
        #expect(overlay.itemViews[2].overflowBadge.isHidden)
    }

    @Test("Minimal announces the windows it does not draw")
    func identifierAnnouncesTheCount() throws {
        LocalizationManager.shared.select("en")
        let (collapsed, _) = try render(.identifier)
        let (expanded, _) = try render(.apps)
        #expect(collapsed.itemViews[1].overflowBadge.isHidden)
        #expect(
            collapsed.itemViews[1].accessibilityLabel()
                == expanded.itemViews[1].accessibilityLabel()
        )
    }

    @Test("Minimal draws an empty identifier in the empty ink")
    func emptyIdentifierDims() throws {
        let (overlay, _) = try render(.identifier)
        let style = try #require(overlay.lastShown?.style)
        #expect(style.shelf.emptyItemAlpha != nil)
        let occupied = try #require(
            overlay.itemViews[1].identifierLabel.textColor
        )
        let empty = try #require(
            overlay.itemViews[2].identifierLabel.textColor
        )
        #expect(occupied == NSColor(kiwiHex: style.idleItemColor))
        #expect(empty == NSColor(kiwiHex: style.emptyItemColor))
        #expect(empty != occupied)
    }

    /// The glide's input: the render records the Space it
    /// expanded, and a hide forgets it, so a bar that reappears
    /// lands rather than gliding from a stale Space.
    @Test("The render records the Space it expanded")
    func renderRecordsTheExpandedSpace() throws {
        let (overlay, _) = try render(.identifier)
        #expect(overlay.shownExpanded == SpaceID("1"))
        overlay.hide()
        #expect(overlay.shownExpanded == nil)
    }

    /// The cue is Minimal's: under Window count an empty Space
    /// already shows no count.
    @Test("Only Minimal dims an empty identifier")
    func onlyMinimalDims() throws {
        let (overlay, _) = try render(.count)
        let style = try #require(overlay.lastShown?.style)
        #expect(
            overlay.itemViews[2].identifierLabel.textColor
                == NSColor(kiwiHex: style.idleItemColor)
        )
    }
}
