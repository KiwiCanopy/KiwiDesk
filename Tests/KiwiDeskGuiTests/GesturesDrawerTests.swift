import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// Shortcuts & Gestures ▸ Mouse & trackpad (#1726): where the
/// drawer mounts, what left Behavior for it, how its entries grey,
/// and the Behavior card's replacement picture.
@Suite("Mouse & trackpad drawer")
struct GesturesDrawerTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let gestures =
        "Sources/KiwiDesk/Settings/Components/Gestures/"

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    private static func squash(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("every pointer sentence places its link")
    @MainActor
    func pointersPlaceTheirLink() {
        LocalizationManager.shared.select("en")
        let slot = CrossReferenceRow.linkSlot
        #expect(GesturesShelfEntries.springLinkProse.contains(slot))
    }

    /// No surface greys for a bar's visibility (#761): a hidden
    /// bar's shortcut shows it, and its gestures then act on it.
    @Test("a hidden bar greys no gesture")
    func hiddenGreysNothing() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .hidden
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        let gestures = ScrollGestureBase.defaults
        for item in GestureItem.allCases
        where item != .scrollStep && item != .spaceStep {
            #expect(!item.isOff(settings, gestures), "\(item)")
        }
    }

    /// Each gesture names the surface it teaches: swapping two
    /// items' surfaces reds here. The entries take theirs from the
    /// item (`GestureEntry+Item`), so this is the one copy.
    @Test("each gesture greys on its own surface")
    func itemNamesItsSurface() {
        let expected: [GestureItem: GestureSurface] = [
            .scrollStep: .windows, .spaceStep: .windows,
            .hoverFocus: .windows, .followFocus: .windows,
            .swap: .windows, .edge: .windows,
            .dropOnSpace: .spaceBar, .spring: .spaceBar,
            .glyphClick: .spaceBar, .glyphPeek: .spaceBar,
            .shelfScroll: .shelf, .contextMenu: .shelf,
            .appBarReorder: .appBar, .appBarHover: .appBar,
        ]
        #expect(Set(expected.keys) == Set(GestureItem.allCases))
        for item in GestureItem.allCases {
            #expect(item.surface == expected[item], "\(item)")
        }
    }

    /// Every entry is built from its item and anchored so a strip
    /// click lands on it, and the card draws the items in their
    /// declared order — the strip's order IS the card's.
    @Test("the entries are the items, in order, each anchored")
    func entriesAreTheItems() throws {
        var all = ""
        for file in [
            "GesturesScrollEntries.swift", "GesturesDrawer.swift",
            "GesturesShelfEntries.swift",
        ] {
            all += Self.squash(try Self.source(Self.gestures + file))
        }
        var at: [GestureItem: String.Index] = [:]
        for item in GestureItem.allCases {
            let entry = try #require(
                all.range(of: "GestureEntry(.\(item.rawValue),"),
                "\(item) has no entry"
            )
            at[item] = entry.lowerBound
            let next =
                all.range(
                    of: "GestureEntry(",
                    range: entry.upperBound..<all.endIndex
                )?.lowerBound ?? all.endIndex
            #expect(
                all[entry.upperBound..<next].contains(
                    ".gestureAnchored(.\(item.rawValue))"
                ),
                "\(item) is not anchored"
            )
        }
        #expect(all.components(separatedBy: "GestureEntry(").count == 15)
        // Within a group, the items' order; across groups, the
        // drawer body's.
        let items = GestureItem.allCases
        for (a, b) in zip(items, items.dropFirst()) where a.group == b.group {
            #expect(try #require(at[a]) < (try #require(at[b])), "\(a) \(b)")
        }
        let drawer = Self.squash(
            try Self.source(Self.gestures + "GesturesDrawer.swift")
        )
        let order = [
            "GesturesScrollEntries(", "focusEntries", "windowEntries",
            "GesturesShelfEntries(",
        ].compactMap { drawer.range(of: $0)?.lowerBound }
        #expect(order.count == 4 && order == order.sorted())
    }

    /// A reason is readable while what it explains is dimmed: the
    /// group greys nothing itself, and the entry greys its
    /// explainer, never the control below it.
    @Test("reasons and controls sit outside the grey")
    func reasonsSitOutsideTheGrey() throws {
        let group = try Self.source(
            Self.gestures + "GesturesShelfEntries.swift"
        )
        #expect(!group.contains("GreyOut("))
        #expect(!group.contains("offReasons"))
        let drawer = try Self.source(
            Self.gestures + "GesturesDrawer.swift"
        )
        #expect(!drawer.contains("GreyOut("))
        let entry = Self.squash(
            try Self.source(Self.gestures + "GestureEntry.swift")
        )
        // One grey, built once and applied to the picture and the
        // sentence: never to the control, nor around the whole.
        #expect(entry.components(separatedBy: "GreyOut(").count == 2)
        #expect(
            entry.contains(
                "privatevardim:GreyOut{GreyOut(active:off)}"
            )
        )
        // The plate's chain and the sentence's each end on `dim`;
        // nothing after the control — through the end of the body
        // — carries it, so the control and the whole stay live.
        #expect(
            entry.contains(
                ".id(moving).accessibilityHidden(true).modifier(dim)"
            )
        )
        #expect(
            entry.contains(
                ".fixedSize(horizontal:false,vertical:true).modifier(dim)"
            )
        )
        let control = try #require(entry.range(of: "control()}"))
        let end = try #require(
            entry.range(
                of: "privatevardim:GreyOut",
                range: control.upperBound..<entry.endIndex
            )
        )
        #expect(!entry[control.upperBound..<end.lowerBound].contains("dim"))
    }

    @Test("the drawer mounts above the layer header")
    func mountsAboveTheLayerHeader() throws {
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        let drawer = try #require(
            body.range(of: "GesturesDrawer(model: model,")
        )
        let header = try #require(body.range(of: "ShortcutsHeader("))
        #expect(drawer.lowerBound < header.lowerBound)
        #expect(
            body.components(separatedBy: "GesturesDrawer(").count
                == 2,
            "the drawer mounts exactly once"
        )
    }
}
