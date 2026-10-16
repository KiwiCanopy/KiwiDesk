import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the View side's lines hold (#2309 rulings 2 and 9): the
/// Profile line only where another profile can be loaded, a broken
/// profile greyed with its reason, KiwiVision's current state
/// marked, and every chip greyed while KiwiDesk boots.
@Suite("View picker items", .serialized)
@MainActor
struct ViewPickItemsTests {
    private typealias Line = ViewPickList.Line

    private let layout = LayoutPickerState(
        space: "3",
        live: .grid,
        drifted: false,
        profile: nil,
        keepArmed: false
    )

    private func items(
        profiles: (String?, [String], Set<String>) = (
            "Laptop", ["Laptop", "Studio", "Old"], ["Old"]
        ),
        visionOn: Bool = false,
        inert: String? = nil
    ) -> [Line: [ViewPickList.Item]] {
        JumpPanelController.items(
            layout: layout,
            profiles: profiles,
            visionOn: visionOn,
            visionChord: "⌃⌥V",
            inert: inert
        )
    }

    @Test("Profile shows only where another profile can load")
    func profileLineNeedsATarget() {
        LocalizationManager.shared.select("en")
        #expect(items()[.profile]?.count == 3)
        let alone = items(profiles: ("Laptop", ["Laptop"], []))
        #expect(alone[.profile]?.isEmpty == true)
        let brokenOnly = items(
            profiles: ("Laptop", ["Laptop", "Old"], ["Old"])
        )
        #expect(brokenOnly[.profile]?.isEmpty == true)
        #expect(
            ViewPickList(layout: layout, items: alone).lines
                == [.layout, .vision]
        )
    }

    @Test("a broken profile is greyed with its reason")
    func brokenProfileIsGreyed() {
        LocalizationManager.shared.select("en")
        let profiles = items()[.profile] ?? []
        #expect(profiles.map(\.isApplicable) == [true, true, false])
        #expect(profiles.last?.refusal == "Can't load")
        #expect(profiles.first?.isCurrent == true)
    }

    @Test("KiwiVision marks its state and carries its shortcut")
    func visionLine() {
        LocalizationManager.shared.select("en")
        let off = items(visionOn: false)[.vision] ?? []
        #expect(off.map(\.pick) == [.vision(false), .vision(true)])
        #expect(off.map(\.isCurrent) == [true, false])
        #expect(off.last?.chord == "⌃⌥V")
        let on = items(visionOn: true)[.vision] ?? []
        #expect(on.map(\.isCurrent) == [false, true])
    }

    @Test("every chip greys while KiwiDesk boots, and says so")
    func inertGreysAll() {
        LocalizationManager.shared.select("en")
        let all = items(inert: ViewPickText.starting).values.flatMap { $0 }
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { !$0.isApplicable })
        #expect(all.allSatisfy { $0.inertReason == "KiwiDesk is starting" })
        let off = items(inert: ViewPickText.starting)[.vision]?.first
        #expect(
            off.map { ViewPickText.spoken($0, on: .vision) }
                == "KiwiVision: Off, current, KiwiDesk is starting"
        )
    }

    /// The boot read is the panel's: a builder fed `inert` by hand
    /// cannot see the consumer drop it.
    @Test("the panel reads boot from Core")
    func bootIsRead() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Jump/JumpPanelController+View.swift"
            )
        let raw = try String(contentsOf: url, encoding: .utf8)
        let source = SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains("letinert=core.bootPhase.isStarting"))
        // Before Start Tiling too (ruling 9), the reason its own.
        #expect(source.contains(":tilingIdle()?ViewPickText.notTiling:nil"))
        #expect(source.occurrences(of: "inert:inert") == 1)
    }

    @Test("no match leaves the digits out of the footer")
    func footerDropsDigitsWithoutMatches() {
        LocalizationManager.shared.select("en")
        func hints(_ count: Int) -> [String] {
            JumpFooter(scope: .view, overflows: false, quickCount: count)
                .hints
        }
        #expect(hints(3).contains("⌘1–3 Quick apply"))
        #expect(hints(1).contains("⌘1 Quick apply"))
        #expect(!hints(0).contains { $0.contains("Quick apply") })
    }

    @Test("the layouts grey where no Space is under the pointer")
    func noSpaceGreysLayouts() {
        LocalizationManager.shared.select("en")
        let lines = JumpPanelController.items(
            layout: nil,
            profiles: ("Laptop", ["Laptop", "Studio"], []),
            visionOn: false,
            visionChord: nil,
            inert: nil
        )
        #expect(lines[.layout]?.allSatisfy { !$0.isApplicable } == true)
        #expect(
            lines[.layout]?.first?.inertReason
                == "No Space under the pointer"
        )
        #expect(lines[.vision]?.allSatisfy(\.isApplicable) == true)
    }
}
