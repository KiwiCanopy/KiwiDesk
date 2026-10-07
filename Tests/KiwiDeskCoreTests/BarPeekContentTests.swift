import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The hover peek's value, drawing and place (#1946, the owner's
/// ruling): every window a row, the count from two, `+n` grouped
/// by app with its icons; the shelf's inks, the badge pill and the
/// hairlines; titles wrapped whole; opening away from the edge.
@Suite("Bar hover peek content", .serialized)
@MainActor
struct BarPeekContentTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    /// A row of `app`'s process — one pid per app name unless
    /// `pid` says otherwise.
    private func row(
        _ id: UInt32,
        app: String,
        title: String,
        icon: NSImage? = nil,
        pid: pid_t? = nil
    ) -> BarWindowRow {
        BarWindowRow(
            window: WindowID(id),
            pid: pid ?? pid_t(app.unicodeScalars.map(\.value).reduce(0, +)),
            app: app,
            title: title,
            icon: icon
        )
    }

    // MARK: - The value

    @Test("Every window counts, an untitled one named as the menu")
    func untitledCounts() {
        LocalizationManager.shared.select("en")
        let content = BarPeekContent(
            rows: [
                row(1, app: "Code", title: "AGENTS.md"),
                row(2, app: "Code", title: ""),
                row(3, app: "Code", title: "Bar.swift"),
            ]
        )
        #expect(content.groups.count == 1)
        #expect(
            content.groups[0].titles
                == ["AGENTS.md", "Untitled Window", "Bar.swift"]
        )
        #expect(content.groups[0].count == 3)
    }

    @Test("The count shows from two windows, never for one")
    func countFromTwo() {
        let one = BarPeekContent(
            rows: [row(1, app: "Notes", title: "A")]
        )
        #expect(one.groups[0].count == nil)
        let two = BarPeekContent(
            rows: [
                row(1, app: "Notes", title: "A"),
                row(2, app: "Notes", title: "B"),
            ]
        )
        #expect(two.groups[0].count == 2)
    }

    /// A lone window titled as its app would repeat the header
    /// word for word, so the header stands alone (owner, device);
    /// a different title, or several windows, keep their rows.
    @Test("A lone window titled as its app shows the header alone")
    func titleEqualToAppIsNotRepeated() {
        LocalizationManager.shared.select("en")
        let same = BarPeekContent(
            rows: [row(1, app: "Claude", title: " Claude ")]
        )
        #expect(same.groups.map(\.app) == ["Claude"])
        #expect(same.groups.map(\.titles) == [[]])
        #expect(same.groups.map(\.windowCount) == [1])
        let other = BarPeekContent(
            rows: [row(1, app: "Claude", title: "New chat")]
        )
        #expect(other.groups.map(\.titles) == [["New chat"]])
        let two = BarPeekContent(
            rows: [
                row(1, app: "Claude", title: "Claude"),
                row(2, app: "Claude", title: "New chat"),
            ]
        )
        #expect(two.groups.map(\.titles) == [["Claude", "New chat"]])
        #expect(two.groups.map(\.count) == [2])
        let untitled = BarPeekContent(
            rows: [row(1, app: "Claude", title: "")]
        )
        #expect(untitled.groups.map(\.titles) == [["Untitled Window"]])
        // The header-only peek draws one label and no hairline.
        let body = BarPeekBody()
        _ = body.build(same, shelf: KiwiShelf())
        #expect(body.labels.map(\.stringValue) == ["Claude"])
        #expect(body.rules.isEmpty)
    }

    /// `+n` mixes apps: one group each, in first-seen order, with
    /// the app's icon, and a count only where a group has two.
    @Test("Mixed apps group per app, with icons")
    func overflowGroups() {
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        let content = BarPeekContent(
            rows: [
                row(1, app: "Messages", title: "Book club", icon: icon),
                row(2, app: "Figma", title: "Hover peek", icon: icon),
                row(3, app: "Figma", title: "Canvas", icon: icon),
            ]
        )
        #expect(content.groups.map(\.app) == ["Messages", "Figma"])
        #expect(
            content.groups.map(\.titles)
                == [["Book club"], ["Hover peek", "Canvas"]]
        )
        #expect(content.groups.map(\.count) == [nil, 2])
        #expect(content.groups.allSatisfy { $0.icon === icon })
    }

    /// Icons answer "which app?", so a list of one app — a glyph,
    /// an App Bar item, or a `+n` hiding one app — carries none,
    /// whatever asked for it (#1945 feeds the same rows).
    @Test("One app's rows carry no icon")
    func oneAppNoIcon() {
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        let content = BarPeekContent(
            rows: [
                row(1, app: "Figma", title: "A", icon: icon),
                row(2, app: "Figma", title: "B", icon: icon),
            ]
        )
        #expect(content.groups.count == 1)
        #expect(content.groups[0].icon == nil)
    }

    /// A glyph's run may span sibling processes of one app (#1785,
    /// Orion): the bars group by app name, so the peek does too —
    /// one group, every window, and no icon, since it names one app.
    @Test("Sibling processes of one app are one group")
    func siblingProcessesShareAGroup() {
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        let content = BarPeekContent(
            rows: [
                row(1, app: "Orion", title: "Work", icon: icon, pid: 10),
                row(2, app: "Orion", title: "Home", icon: icon, pid: 20),
                row(3, app: "Orion", title: "Mail", icon: icon, pid: 10),
            ]
        )
        #expect(content.groups.map(\.app) == ["Orion"])
        #expect(
            content.groups.map(\.titles) == [["Work", "Home", "Mail"]]
        )
        #expect(content.groups.map(\.count) == [3])
        #expect(content.groups[0].icon == nil)
    }

    // MARK: - The drawing

    /// The owner's look: the header in the full item ink (its
    /// weight and size carry the hierarchy), titles in the
    /// item ink, the count in the bar's badge, a hairline between
    /// every two windows and every two apps.
    @Test("The body draws the shelf's inks, pill and hairlines")
    func bodyDrawsTheRuledLook() throws {
        var shelf = KiwiShelf()
        shelf.groupBadgeColor = "#445566"
        let body = BarPeekBody()
        _ = body.build(
            BarPeekContent(
                rows: [
                    row(1, app: "A", title: "One"),
                    row(2, app: "A", title: "Two"),
                    row(3, app: "A", title: "Three"),
                    row(4, app: "B", title: "Four"),
                ]
            ),
            shelf: shelf
        )
        // Two headers, four titles.
        #expect(body.labels.count == 6)
        let header = try #require(body.labels.first)
        #expect(header.stringValue == "A")
        // The derived step under the titles (owner ruling).
        #expect(shelf.peekHeaderColor != shelf.itemColor)
        #expect(
            header.textColor == NSColor(kiwiHex: shelf.peekHeaderColor)
        )
        let one = try #require(body.labels.dropFirst().first)
        #expect(one.textColor == NSColor(kiwiHex: shelf.itemColor))
        // Only A has two or more windows.
        #expect(body.pills.map(\.number.stringValue) == ["3"])
        let pill = try #require(body.pills.first)
        #expect(
            pill.layer?.backgroundColor
                == NSColor(kiwiHex: shelf.groupBadgeColor).cgColor
        )
        // The window glyph leads the number inside the pill.
        #expect(pill.glyph.image != nil)
        #expect(pill.glyph.frame.maxX <= pill.number.frame.minX)
        #expect(pill.frame.height == BarPeekBody.Metrics.pillHeight)
        // Two between A's three windows, one between the apps.
        #expect(body.rules.count == 3)
        #expect(
            body.rules.allSatisfy {
                $0.frame.height == BarDivider.ruleThickness
            }
        )
    }

    /// The header's step is derived: a palette where 0.75 of its
    /// item ink would miss the floor on the peek's grounds keeps the
    /// full ink — a custom palette nobody measured.
    @Test("A low-contrast palette's header falls back to full ink")
    func headerFallsBackToFullInk() {
        var shelf = KiwiShelf()
        shelf.itemColor = "#5A5A5A"
        shelf.fillColor = "#3A3A3CB3"
        #expect(shelf.peekHeaderColor == shelf.itemColor)
        // The default palette holds the step.
        let kiwi = KiwiShelf()
        #expect(
            kiwi.peekHeaderColor
                == kiwi.itemColor(atShare: KiwiShelf.peekHeaderAlpha)
        )
    }

    /// A long title wraps whole inside the peek's widest, never cut.
    @Test("A long title wraps to the peek's width")
    func longTitleWraps() throws {
        let long = String(
            repeating: "SpaceBarWindowMenu.swift — kiwidesk — ",
            count: 4
        )
        let body = BarPeekBody()
        let size = body.build(
            BarPeekContent(
                rows: [row(1, app: "Code", title: long)]
            ),
            shelf: KiwiShelf()
        )
        #expect(size.width <= BarPeekBody.Metrics.maxWidth)
        let title = try #require(body.labels.last)
        #expect(title.stringValue == long)
        let line = BarPeekBody.lineHeight(title.font)
        #expect(title.frame.height > 2 * line, "it wraps, not cuts")
        #expect(title.frame.maxY < size.height)
    }

    // MARK: - Placement

    /// Opens away from the bar's edge, across the strip and off it.
    @Test("It opens away from the bar's edge, on its screen")
    func opensAwayFromTheEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = CGSize(width: 200, height: 80)
        let top = CGRect(x: 0, y: 860, width: 1440, height: 40)
        let anchor = CGRect(x: 300, y: 870, width: 20, height: 20)
        let below = BarPeekPanel.origin(
            size: size,
            edge: .top,
            anchor: anchor,
            strip: top,
            visible: screen
        )
        #expect(below.y + size.height <= top.minY)
        let bottom = CGRect(x: 0, y: 0, width: 1440, height: 40)
        let above = BarPeekPanel.origin(
            size: size,
            edge: .bottom,
            anchor: CGRect(x: 300, y: 10, width: 20, height: 20),
            strip: bottom,
            visible: screen
        )
        #expect(above.y >= bottom.maxY)
        let left = CGRect(x: 0, y: 0, width: 40, height: 900)
        let beside = BarPeekPanel.origin(
            size: size,
            edge: .left,
            anchor: CGRect(x: 10, y: 400, width: 20, height: 20),
            strip: left,
            visible: screen
        )
        #expect(beside.x >= left.maxX)
        // An item at the screen's end keeps the peek on screen.
        let edge = BarPeekPanel.origin(
            size: size,
            edge: .top,
            anchor: CGRect(x: 1430, y: 870, width: 10, height: 20),
            strip: top,
            visible: screen
        )
        #expect(edge.x + size.width <= screen.maxX)
    }
}
