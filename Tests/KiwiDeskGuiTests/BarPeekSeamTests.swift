import Foundation
import Testing

/// The hover peek's wiring a behavioural test cannot see (#1946):
/// its glass decided through the one gate where it renders, its
/// item re-checked after the shelf's hover re-read, its content read
/// from state alone, each anchor answering a press as its click
/// rules, its rows picking through the window menu's one door, and
/// no bar view left registering the system tooltip it replaces.
@Suite("Bar hover peek seams (#1946)")
struct BarPeekSeamTests {
    private static var bar: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Bar")
    }

    private static func source(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: bar.appendingPathComponent(file)
        )
    }

    /// One gate read on the stored shelf, which the body names
    /// nowhere beside it — a second read would draw the stored
    /// glass under Reduce transparency (#1374).
    @Test("the peek renders its glass through the gate, once")
    func peekTakesTheGate() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "func show(",
                in: try Self.source("BarPeekPanel.swift")
            ),
            "BarPeekPanel.show is gone"
        )
        #expect(
            SourceScan.callSites(
                in: Array(body),
                for: "LiquidGlassGate.rendered"
            ).count == 1
        )
        let stored = try #require(
            SourceScan.callArguments(
                of: "LiquidGlassGate.rendered(",
                in: body
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        #expect(stored == "stored")
        #expect(body.occurrences(of: stored) == 1)
    }

    /// The re-read may move the pointer onto another item, which
    /// the peek then follows; only after it is the peeked item's
    /// place worth comparing.
    @Test("the relayout re-checks the peek after the hover re-read")
    func relayoutChecksAfterTheReRead() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "func relayout(",
                in: try Self.source("ShelfManager.swift")
            )
        )
        let check = try #require(body.range(of: "peek.syncToAnchor()"))
        let reRead = try #require(
            body.range(of: "syncHoverToPointer()", options: .backwards)
        )
        #expect(reRead.upperBound <= check.lowerBound)
    }

    /// The peek replaced the system tooltip on every bar item. A
    /// menu ROW's tooltip — `SpaceBarWindowMenu`'s `NSMenuItem`,
    /// which carries a cut title whole — is a menu's, not a bar
    /// view's, and is the one exemption.
    private static let tooltipExempt = [
        "SpaceBarWindowMenu.swift": "an NSMenuItem's toolTip, a menu row's"
    ]

    @Test("no bar view registers a system tooltip")
    func noBarTooltip() throws {
        var found: [String] = []
        var exemptSeen: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.bar) {
            let name = file.lastPathComponent
            let text = try SourceScan.strippedSource(at: file)
            for needle in ["addToolTip(", "NSViewToolTipOwner"]
            where text.contains(needle) {
                found.append("\(name): \(needle)")
            }
            // An assignment however it is spaced, never a comparison.
            guard text.contains(/toolTip\s*=(?!=)/) else { continue }
            if Self.tooltipExempt[name] != nil {
                exemptSeen.insert(name)
            } else {
                found.append("\(name): toolTip =")
            }
        }
        #expect(found.isEmpty, "\(found)")
        // The exemption still fires, so the needle still matches.
        #expect(exemptSeen == Set(Self.tooltipExempt.keys))
    }

    /// The peek's content is read on every show and swap — the
    /// relayout's re-read on the switch path included — so it reads
    /// STATE alone: the menu rows' enablement asks the compositor
    /// twice a window (#1925) and may log a raise refusal.
    @Test("the peek's content path reads no compositor")
    func contentReadsStateOnly() throws {
        let app = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/App")
        let content = try #require(
            SourceScan.declarationBody(
                after: "func barPeekContent(",
                in: try SourceScan.strippedSource(
                    at: app.appendingPathComponent("KiwiCore+BarPeek.swift")
                )
            )
        )
        #expect(content.contains("barWindowRows("))
        let rows = try #require(
            SourceScan.declarationBody(
                after: "func barWindowRows(",
                in: try SourceScan.strippedSource(
                    at: app.appendingPathComponent(
                        "KiwiCore+SpaceBarClick.swift"
                    )
                )
            )
        )
        let bodies = [
            ("barPeekContent", content),
            ("barWindowRows", rows),
        ]
        for (name, body) in bodies {
            for needle in Self.compositorReads where body.contains(needle) {
                Issue.record("\(name) reaches \(needle)")
            }
        }
        // A level down: the rows' one call out of state, the icon.
        #expect(rows.contains("BarIconCache.icon("))
        for file in try SourceScan.swiftSources(under: Self.bar)
        where file.lastPathComponent.hasPrefix("BarPeek")
            || file.lastPathComponent == "BarIconCache.swift"
        {
            let text = try SourceScan.strippedSource(at: file)
            for needle in Self.compositorReads where text.contains(needle) {
                Issue.record("\(file.lastPathComponent) reaches \(needle)")
            }
        }
    }

    /// The compositor's seams, as a class: the focus door's raise
    /// gate, the on-screen and shown-Desktop reads, the WindowServer
    /// window list, the Desktop reads — and the menu rows, which
    /// take the raise gate.
    private static let compositorReads = [
        "raiseCrossesDesktops", "windowIsOnScreen(",
        "windowIsOnShownDesktop(", "FloatDetection.", "NativeSpaces.",
        "spaceBarMenuRows(",
    ]

    /// Every view that reports the pointer to the peek, and the
    /// views it may hand as the anchor — the one copy of who
    /// anchors it. Derived from the `peek?.pointer(` callers, so a
    /// new reporter reds until it is written here; a reporter
    /// gaining an anchor (#1945's collapsed chip) widens its set.
    private static let anchors: [String: Set<String>] = [
        "SpaceBarItemView+Hover.swift": ["SpaceBarGlyphTarget.swift"],
        "AppBarItemView+HoverTitle.swift": ["AppBarItemView.swift"],
    ]

    /// What an anchor's press does to the peek (#1946, amendment
    /// 2): an App Bar item's press is a pick, so it closes the peek
    /// after its Control-click guard; a glyph's press only arms its
    /// click, which Core turns into a pin or a pick.
    private static let pressDismisses = [
        "AppBarItemView.swift": true,
        "SpaceBarGlyphTarget.swift": false,
    ]

    @Test("every anchor answers a press as its click rules")
    func anchorsAnswerAPress() throws {
        var reporters: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.bar) {
            let text = try SourceScan.strippedSource(at: file)
            if text.contains("peek?.pointer(") {
                reporters.insert(file.lastPathComponent)
            }
        }
        #expect(reporters == Set(Self.anchors.keys), "\(reporters)")
        let anchors = Set(Self.anchors.values.joined())
        #expect(anchors == Set(Self.pressDismisses.keys))
        for anchor in anchors {
            let body = try #require(
                SourceScan.declarationBody(
                    after: "func mouseDown(",
                    in: try Self.source(anchor)
                ),
                "\(anchor) takes no press"
            )
            let guardHit = try #require(
                body.range(of: "openControlClickMenu("),
                "\(anchor)"
            )
            let dismiss = body.range(of: "peek?.dismiss()")
            #expect(
                (dismiss != nil) == Self.pressDismisses[anchor],
                "\(anchor)"
            )
            if let dismiss {
                #expect(guardHit.upperBound <= dismiss.lowerBound, "\(anchor)")
            }
        }
        // A glyph's click: a one-window glyph's pick closes the peek
        // ahead of its focus; a list pins it.
        let click = try #require(
            SourceScan.declarationBody(
                after: "func pickFromSpaceBar(",
                in: try Self.app("KiwiCore+SpaceBarClick.swift")
            )
        )
        let closes = try #require(click.range(of: "shelves.peek.dismiss()"))
        let focus = try #require(click.range(of: "focusFromSpaceBar("))
        #expect(closes.upperBound <= focus.lowerBound)
        #expect(click.contains("pinPeek(pick)"))
        #expect(!click.contains("SpaceBarWindowMenu.make("))
    }

    private static func app(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDeskCore/App")
                .appendingPathComponent(file)
        )
    }

    /// A peek row and a window menu row pick through ONE door,
    /// `pickBarRow`, so the two lists cannot focus two ways (#1946):
    /// the menu has one builder, whose rows take it; the peek's
    /// pick takes it; and the focus behind it is called from that
    /// door and the one-window glyph's click alone.
    @Test("a peek row's pick is the window menu's pick")
    func oneBarRowPick() throws {
        let click = try Self.app("KiwiCore+SpaceBarClick.swift")
        let builder = try #require(
            SourceScan.declarationBody(
                after: "func presentBarWindowMenu(",
                in: click
            )
        )
        let made = try #require(builder.range(of: "SpaceBarWindowMenu.make("))
        #expect(
            builder[made.upperBound...].contains("pickBarRow(id, on: space)")
        )
        let wiring = try #require(
            SourceScan.declarationBody(
                after: "peek.pick = {",
                in: try Self.app("KiwiCore+BarPeek.swift")
            )
        )
        #expect(wiring.contains("pickBarRow(id, on: space)"))
        let picked = try #require(
            SourceScan.declarationBody(
                after: "func picked(",
                in: try Self.source("BarPeek+Hold.swift")
            )
        )
        #expect(picked.contains("pick(window, shown.space)"))
        // Sources-wide: one menu builder, two focus call sites.
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        var builders = 0
        var focuses: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.strippedSource(at: file)
            builders += text.occurrences(of: "SpaceBarWindowMenu.make(")
            let calls =
                text.occurrences(of: "focusFromSpaceBar(")
                - text.occurrences(of: "func focusFromSpaceBar(")
            if calls > 0 { focuses[file.lastPathComponent] = calls }
        }
        #expect(builders == 1)
        #expect(focuses == ["KiwiCore+SpaceBarClick.swift": 2])
    }
}
