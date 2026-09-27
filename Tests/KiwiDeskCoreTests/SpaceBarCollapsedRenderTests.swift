import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A collapsed Space item as the live bar draws it (#1683): its
/// count cell fits the length the plan measured; the count reads
/// as a whole count; Minimal still announces the windows; an
/// empty identifier takes the empty ink. Driven through
/// `SpaceBarManager.sync`. The glide's wiring is
/// `SpaceBarGlideWiringTests`.
@Suite("Space bar collapsed render", .serialized)
@MainActor
struct SpaceBarCollapsedRenderTests {
    private func render(
        _ content: SpaceBarStyle.InactiveContent
    ) throws -> SpaceBarOverlay {
        LiquidGlassGate.override = { false }
        let manager = SpaceBarManager()
        manager.sync([collapsedBar(content)])
        return try #require(manager.overlayForTesting(barTitleDisplay))
    }

    /// The count cell is reserved by the length and drawn by the
    /// view's layout, which read one input (`badgeCount`): a
    /// length measuring the cleared `overflow` instead leaves the
    /// badge hanging past the item's end.
    @Test("A collapsed count's cell fits the planned length")
    func countCellFitsThePlan() throws {
        let overlay = try render(.count)
        let view = overlay.itemViews[1]
        view.layoutSubtreeIfNeeded()
        let depth = barTitleStrip.height
        let bare = SpaceBarItemView.autoLength(
            appCount: 0,
            depth: depth,
            glyphGap: 0
        )
        #expect(view.frame.width > bare)
        #expect(!view.overflowBadge.isHidden)
        #expect(view.overflowBadge.frame.maxX <= view.bounds.width)
        // Minimal reserves nothing past the identifier.
        let minimal = try render(.identifier)
        #expect(minimal.itemViews[1].frame.width == bare)
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

    @Test("Minimal announces the windows it does not draw")
    func identifierAnnouncesTheCount() throws {
        LocalizationManager.shared.select("en")
        let collapsed = try render(.identifier)
        let expanded = try render(.apps)
        #expect(collapsed.itemViews[1].overflowBadge.isHidden)
        #expect(
            collapsed.itemViews[1].accessibilityLabel()
                == expanded.itemViews[1].accessibilityLabel()
        )
        #expect(
            collapsed.itemViews[1].accessibilityLabel()
                == "Space 2, windows: 3, not current"
        )
    }

    @Test("Minimal draws an empty identifier in the empty ink")
    func emptyIdentifierDims() throws {
        let overlay = try render(.identifier)
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

    /// The cue is Minimal's: under Window count an empty Space
    /// already shows no count, and under Apps no glyphs.
    @Test(
        "Only Minimal dims an empty identifier",
        arguments: [
            SpaceBarStyle.InactiveContent.count, .apps,
        ]
    )
    func onlyMinimalDims(content: SpaceBarStyle.InactiveContent) throws {
        let overlay = try render(content)
        let style = try #require(overlay.lastShown?.style)
        let drawn = overlay.itemViews[2].identifierLabel.textColor
        #expect(drawn == NSColor(kiwiHex: style.idleItemColor))
        #expect(drawn != NSColor(kiwiHex: style.emptyItemColor))
    }
}

/// Space 1 shown unless `active` says otherwise; Space 2 holds
/// three windows, Space 3 none, each collapsed to `content`.
@MainActor
func collapsedBar(
    _ content: SpaceBarStyle.InactiveContent,
    active: Int = 1,
    boxedGlass: Bool = false
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
        [app("Notes", 1)], [app("Mail", 2), app("Web", 1)], [],
    ]
    let items = apps.enumerated().map { index, apps in
        SpaceBarOverlay.Item(
            space: SpaceID("\(index + 1)"),
            spaceGlyph: .text("\(index + 1)", tinted: true),
            apps: apps,
            active: index + 1 == active,
            overflow: 0,
            focusInOverflow: false
        ).collapsed(to: content)
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
