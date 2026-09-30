import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A collapsed Space item as the live bar draws it (#1683): the
/// count is a disc on the identifier's corner that adds no length
/// to the item; it reads as a whole count; the label announces
/// the exact windows; an empty identifier draws no disc and takes
/// the empty ink. Driven through `SpaceBarManager.sync`. The
/// glide's wiring is `SpaceBarGlideWiringTests`.
@Suite("Space bar collapsed render", .serialized)
@MainActor
struct SpaceBarCollapsedRenderTests {
    private func render(
        _ content: SpaceBarStyle.InactiveContent,
        held: Bool = false,
        windows: Int = 3
    ) throws -> SpaceBarOverlay {
        LiquidGlassGate.override = { false }
        let manager = SpaceBarManager()
        manager.sync([
            collapsedBar(content, held: held, windows: windows)
        ])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    /// The plan measures the identifier alone, and the disc sits
    /// inside the identifier's cell rather than a cell of its own.
    @Test("The count disc rides the identifier's cell")
    func discRidesTheIdentifier() throws {
        let overlay = try render(.count)
        let view = overlay.itemViews[1]
        view.layoutSubtreeIfNeeded()
        let depth = barTitleStrip.height
        let bare = SpaceBarItemView.autoLength(
            appCount: 0,
            contentDepth: depth,
            glyphGap: 0,
            ends: view.ends
        )
        #expect(view.frame.width == bare)
        let disc = view.overflowBadge.frame
        #expect(!view.overflowBadge.isHidden)
        #expect(disc.maxX <= view.bounds.width)
        // A corner disc of the badge family's size, on the
        // identifier cell's top-trailing corner.
        let cell = view.cellLength
        let identifier = CGRect(
            x: SpaceBarItemView.pad + view.ends.leading,
            y: (view.bounds.height - cell) / 2,
            width: cell,
            height: cell
        )
        #expect(disc.width >= StateBadgeMetrics.side(cell: cell) - 1)
        #expect(disc.width < cell)
        #expect(disc.intersects(identifier))
        #expect(abs(disc.maxX - (identifier.maxX + 1)) <= 1)
        #expect(disc.midY < view.bounds.midY)
    }

    /// The held asterisk owns the top corner (#1507), so the disc
    /// takes the bottom one rather than covering it.
    @Test(
        "A held Space's disc takes the bottom corner",
        arguments: [3, 12]
    )
    func heldDiscMovesDown(windows: Int) throws {
        let view = try render(.count, held: true, windows: windows)
            .itemViews[1]
        view.layoutSubtreeIfNeeded()
        #expect(!view.markerBadge.isHidden)
        #expect(view.overflowBadge.frame.midY > view.bounds.midY)
        #expect(!view.overflowBadge.frame.intersects(view.markerBadge.frame))
    }

    /// Past nine the disc reads "9+" and stays a disc, while the
    /// label announces the exact count.
    @Test("A crowded Space's disc reads 9+")
    func crowdedDiscCaps() throws {
        LocalizationManager.shared.select("en")
        let cap = SpaceBarItemView.Collapse.discCap
        let view = try render(.count, windows: 12).itemViews[1]
        try #require(12 > cap)
        #expect(view.overflowBadge.stringValue == "\(cap)+")
        #expect(
            view.accessibilityLabel()
                == "Space 2, windows: 12, not current"
        )
    }

    @Test("Window count draws the whole count, unprefixed")
    func countReadsWhole() throws {
        let overlay = try render(.count)
        let other = overlay.itemViews[1]
        #expect(!other.overflowBadge.isHidden)
        #expect(other.overflowBadge.stringValue == "3")
        // The state badges go with the glyphs.
        #expect(other.stickyBadgeViews.isEmpty)
        #expect(other.floatingBadgeViews.isEmpty)
        #expect(overlay.itemViews[2].overflowBadge.isHidden)
    }

    @Test("A collapsed Space announces its windows")
    func collapsedAnnouncesTheCount() throws {
        LocalizationManager.shared.select("en")
        let collapsed = try render(.count)
        let expanded = try render(.apps)
        #expect(
            collapsed.itemViews[1].accessibilityLabel()
                == expanded.itemViews[1].accessibilityLabel()
        )
        #expect(
            collapsed.itemViews[1].accessibilityLabel()
                == "Space 2, windows: 3, not current"
        )
    }

    /// Under either content an empty Space's identifier dims: the
    /// cue says the same thing whether the others draw apps or a
    /// count (owner, 2026-09-27).
    @Test(
        "An empty Space's identifier takes the empty ink",
        arguments: [
            SpaceBarStyle.InactiveContent.count, .apps,
        ]
    )
    func emptyIdentifierDims(
        content: SpaceBarStyle.InactiveContent
    ) throws {
        let overlay = try render(content)
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
}

/// Space 1 shown unless `active` says otherwise; Space 2 holds
/// three windows, Space 3 none, each collapsed to `content`.
@MainActor
func collapsedBar(
    _ content: SpaceBarStyle.InactiveContent,
    active: Int = 1,
    boxedGlass: Bool = false,
    held: Bool = false,
    windows: Int = 3
) -> SpaceBarManager.Bar {
    let app = { (name: String, count: Int) in
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
    let apps = [
        [app("Notes", 1)], [app("Mail", windows - 1), app("Web", 1)],
        [],
    ]
    let items = apps.enumerated().map { index, apps in
        var item = SpaceBarOverlay.Item(
            space: SpaceID("\(index + 1)"),
            spaceGlyph: .text("\(index + 1)", tinted: true),
            apps: apps,
            active: index + 1 == active,
            after: .none
        ).collapsed(to: content)
        if held, index == 1 {
            item.held = .init(screenName: "Dell", originName: nil)
        }
        return item
    }
    var style = paintedSpaceBar(front: nil).style
    style.inactiveContent = content
    if boxedGlass {
        style.backgroundStyle = .boxed
        style.liquidGlass = true
    }
    return SpaceBarManager.Bar(
        display: barTitleDisplay,
        items: items,
        frontApp: nil,
        frontWindow: nil,
        strip: barTitleStrip,
        style: style,
        stateMarkColors: StateMarkColors(
            sticky: "#ffffff",
            floating: "#ffffff"
        )
    )
}
