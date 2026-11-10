import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// Shortcuts ▸ Mouse & Trackpad (#1726, #3184): where the part
/// mounts, its groups and their entries, and how the entries grey.
@Suite("Mouse & Trackpad part")
struct GesturesPartTests {
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

    /// Every entry is built from its item and anchored so a hit
    /// lands on it, and the part draws the items in their declared
    /// order, its groups by where the hand is.
    @Test("the entries are the items, in order, each anchored")
    func entriesAreTheItems() throws {
        var all = ""
        for file in [
            "GesturesPart.swift", "GesturesScrollEntries.swift",
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
            try Self.source(Self.gestures + "GesturesPart.swift")
        )
        let order = [
            "SettingsCatalog.shortcuts.gesturesOnWindows",
            "focusEntries", "windowEntries",
            "SettingsCatalog.shortcuts.gesturesModifier",
            "GesturesScrollEntries(", "GesturesModifierDragRows(",
            "SettingsCatalog.shortcuts.gesturesOnShelf",
            "GesturesShelfEntries(",
        ].compactMap { drawer.range(of: $0)?.lowerBound }
        #expect(order.count == 8 && order == order.sorted())
        // Group order follows the items' declared groups.
        let ranks = GestureItem.allCases.compactMap {
            GestureItem.Group.allCases.firstIndex(of: $0.group)
        }
        #expect(ranks.count == items.count && ranks == ranks.sorted())
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
            Self.gestures + "GesturesPart.swift"
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

    @Test("the part mounts once, alone on Mouse & Trackpad")
    func mountsAlone() throws {
        #expect(ShortcutsPagePart.parts(in: .mouse) == [.gestures])
        let body = try Self.source(
            "Sources/KiwiDesk/Settings/Sections/ShortcutsSection.swift"
        )
        let squashed = body.filter { !$0.isWhitespace }
        #expect(
            squashed.contains(
                "case.gestures:GesturesPart(model:model,"
            ),
            "the gestures part draws the groups"
        )
        #expect(
            body.components(separatedBy: "GesturesPart(").count == 2,
            "the part mounts exactly once"
        )
    }
}
