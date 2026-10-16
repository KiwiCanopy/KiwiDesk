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
        vision: VisionActive = .off,
        lenses: [VisionLensChoice] = [],
        inert: String? = nil
    ) -> [Line: [ViewPickList.Item]] {
        JumpPanelController.items(
            layout: layout,
            profiles: profiles,
            vision: (vision, lenses),
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
        let off = items(vision: .off)[.vision] ?? []
        #expect(off.map(\.pick) == [.visionOff, .vision(lens: nil)])
        #expect(off.map(\.isCurrent) == [true, false])
        #expect(off.last?.chord == "⌃⌥V")
        let on = items(vision: .plain)[.vision] ?? []
        #expect(on.map(\.isCurrent) == [false, true])
    }

    /// Ruling 41: a chip per lens after Focused window, the lens on
    /// marked; a lens Core refuses greys with the reason it names.
    @Test("each lens gets a chip, an empty one greyed")
    func lensChips() {
        LocalizationManager.shared.select("en")
        let lenses = [
            VisionLensChoice(name: "Writing"),
            VisionLensChoice(name: "Calls", refusal: .noApps),
        ]
        let line = items(vision: .lens("Writing"), lenses: lenses)[.vision]
        let chips = line ?? []
        #expect(
            chips.map(\.pick) == [
                .visionOff, .vision(lens: nil), .vision(lens: "Writing"),
                .vision(lens: "Calls"),
            ]
        )
        #expect(chips.map(\.name).suffix(2) == ["Writing", "Calls"])
        #expect(chips.map(\.isCurrent) == [false, false, true, false])
        #expect(chips.map(\.isApplicable) == [true, true, true, false])
        #expect(chips.last?.refusal == "No apps yet")
        #expect(
            chips.last.map { ViewPickText.spoken($0, on: .vision) }
                == "KiwiVision: Calls, No apps yet"
        )
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
        #expect(source.contains(":ViewPickText.held(hold())"))
        #expect(source.occurrences(of: "inert:inert") == 1)
    }

    /// A builder test cannot see the pick reach Core, nor the
    /// line re-read when a chord or a verb changes KiwiVision.
    @Test("a lens chip turns its lens on, and the line follows")
    func lensWiring() throws {
        func flat(_ path: String) throws -> String {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
            let raw = try String(contentsOf: url, encoding: .utf8)
            return SourceScan.stripComments(raw)
                .split(whereSeparator: \.isWhitespace).joined()
        }
        let panel = try flat(
            "Sources/KiwiDesk/Jump/JumpPanelController+View.swift"
        )
        #expect(
            panel.contains(
                "case.vision(lens:letname?):core.setKiwiVision(.lens(name))"
            )
        )
        #expect(
            panel.contains(
                "vision:(core.kiwiVisionActive,core.kiwiVisionLensChoices)"
            )
        )
        #expect(
            panel.contains(
                "guardisOpen,letmodel=currentModel,model.scope==.view"
                    + "else{return}model.reloadView()"
            )
        )
        let delegate = try flat(
            "Sources/KiwiDesk/AppDelegate+KiwiVision.swift"
        )
        // Both triggers reach the one funnel, which reaches the chips.
        #expect(
            delegate.contains(
                "core.onAppWideChange={[weakself]in"
                    + "self?.visionReadersChanged()}"
            )
        )
        #expect(
            delegate.contains(
                "core.vision.onChange={[weakself]activein"
                    + "self?.visionReadersChanged()"
            )
        )
        #expect(
            delegate.contains(
                "funcvisionReadersChanged(){"
                    + "dashboardIfCreated?.model.objectWillChange.send()"
                    + "jumpPanel?.reloadViewIfShown()}"
            )
        )
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
            vision: (.off, []),
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
