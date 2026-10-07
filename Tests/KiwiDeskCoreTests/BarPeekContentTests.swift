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

    /// Two processes sharing a name are two apps: grouped by pid,
    /// each headed by its own name.
    @Test("Groups key on the process, not the name")
    func groupsKeyOnThePid() {
        let content = BarPeekContent(
            rows: [
                row(1, app: "Chrome", title: "Work", pid: 10),
                row(2, app: "Chrome", title: "Home", pid: 20),
                row(3, app: "Chrome", title: "Mail", pid: 10),
            ]
        )
        #expect(content.groups.map(\.app) == ["Chrome", "Chrome"])
        #expect(
            content.groups.map(\.titles) == [["Work", "Mail"], ["Home"]]
        )
    }

    // MARK: - The drawing

    /// The owner's look: the header in the idle ink, titles in the
    /// item ink, the count in the bar's badge, a hairline between
    /// every two windows and every two apps.
    @Test("The body draws the shelf's inks, pill and hairlines")
    func bodyDrawsTheRuledLook() throws {
        var shelf = KiwiShelf()
        shelf.itemColor = "#102030"
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
        #expect(
            header.textColor == NSColor(kiwiHex: shelf.idleItemColor)
        )
        let one = try #require(body.labels.dropFirst().first)
        #expect(one.textColor == NSColor(kiwiHex: shelf.itemColor))
        // Only A has two or more windows.
        #expect(body.pills.map(\.stringValue) == ["3"])
        #expect(
            body.pills.first?.layer?.backgroundColor
                == NSColor(kiwiHex: shelf.groupBadgeColor).cgColor
        )
        // Two between A's three windows, one between the apps.
        #expect(body.rules.count == 3)
        #expect(
            body.rules.allSatisfy {
                $0.frame.height == BarDivider.ruleThickness
            }
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

    /// A peek taller than the usable room on its side is cut to it,
    /// so it never covers its bar; one that fits keeps its height.
    @Test("A tall peek is capped to the usable area")
    func tallPeekIsCapped() {
        // The menu bar and the Dock leave a smaller usable area.
        let visible = CGRect(x: 0, y: 80, width: 1440, height: 790)
        let top = CGRect(x: 0, y: 830, width: 1440, height: 40)
        let tall = CGSize(width: 200, height: 2000)
        let capped = BarPeekPanel.capped(
            tall,
            edge: .top,
            strip: top,
            visible: visible
        )
        #expect(capped.width == tall.width)
        #expect(capped.height < tall.height)
        let origin = BarPeekPanel.origin(
            size: capped,
            edge: .top,
            anchor: CGRect(x: 300, y: 840, width: 20, height: 20),
            strip: top,
            visible: visible
        )
        #expect(origin.y >= visible.minY)
        #expect(origin.y + capped.height <= top.minY)
        let bottom = CGRect(x: 0, y: 80, width: 1440, height: 40)
        let up = BarPeekPanel.capped(
            tall,
            edge: .bottom,
            strip: bottom,
            visible: visible
        )
        #expect(bottom.maxY + up.height <= visible.maxY)
        let small = CGSize(width: 200, height: 80)
        #expect(
            BarPeekPanel.capped(
                small,
                edge: .top,
                strip: top,
                visible: visible
            ) == small
        )
    }
}
