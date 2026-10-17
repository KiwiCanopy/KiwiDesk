import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the View side's lines hold (#2309 rulings 2 and 9, #2359):
/// the Profile line always, ending in Save as New Profile…, a broken
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
            lensChord: { _ in nil },
            offersNewLens: true,
            inert: inert
        )
    }

    /// The Profile line always shows, ending in Save as New
    /// Profile… — alone where nothing is saved (#2359 ruling 3,
    /// amending #2309 ruling 2).
    @Test("Profile always shows, ending in Save as New Profile…")
    func profileLineEndsInTheSaveChip() {
        LocalizationManager.shared.select("en")
        let all = items()[.profile] ?? []
        #expect(
            all.map(\.pick) == [
                .profile("Laptop"), .profile("Studio"), .profile("Old"),
                .newProfile,
            ]
        )
        #expect(all.last?.name == "Save as New Profile…")
        let none = items(profiles: (nil, [], []))
        #expect(none[.profile]?.map(\.pick) == [.newProfile])
        #expect(
            ViewPickList(layout: layout, kiwiVisionOn: false, items: none)
                .lines
                == [.layout, .profile, .vision]
        )
    }

    @Test("a broken profile is greyed with its reason")
    func brokenProfileIsGreyed() {
        LocalizationManager.shared.select("en")
        let profiles = (items()[.profile] ?? []).dropLast()
        #expect(profiles.map(\.isApplicable) == [true, true, false])
        #expect(profiles.last?.refusal == "Can't load")
        #expect(profiles.first?.isCurrent == true)
    }

    @Test("KiwiVision marks its state and carries its shortcut")
    func visionLine() {
        LocalizationManager.shared.select("en")
        let off = items(vision: .off)[.vision] ?? []
        // No Off chip; the line ends in New Lens… (#2103 rulings
        // 56, 57).
        #expect(off.map(\.pick) == [.vision(lens: nil), .newLens])
        #expect(off.map(\.isCurrent) == [false, false])
        #expect(off[0].name == "Default")
        #expect(off[0].chord == "⌃⌥V")
        #expect(off.last?.name == "New Lens…")
        let on = items(vision: .plain)[.vision] ?? []
        #expect(on.map(\.isCurrent) == [true, false])
        let lua =
            JumpPanelController.items(
                layout: nil,
                profiles: (nil, [], []),
                vision: (.off, []),
                visionChord: nil,
                lensChord: { _ in nil },
                offersNewLens: false,
                inert: nil
            )[.vision] ?? []
        // A Lua-owned setup greys it rather than hiding it.
        let luaNew = lua.first { $0.pick == .newLens }
        #expect(luaNew?.isApplicable == false)
        #expect(luaNew?.refusal == "Lenses come from init.lua")
    }

    /// Ruling 41: a chip per lens after Default, the lens on
    /// marked, New Lens… still last (ruling 57); a lens with no
    /// apps is left out, Settings being where it gains some (owner
    /// ruling 2026-10-17).
    @Test("each lens gets a chip, an empty one is left out")
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
                .vision(lens: nil), .vision(lens: "Writing"), .newLens,
            ]
        )
        #expect(chips.map(\.isCurrent) == [false, true, false])
        // Ruling 15: a lens the live profile leaves out says which.
        let away = items(
            vision: .off,
            lenses: [
                VisionLensChoice(
                    name: "Writing",
                    refusal: .outOfReach(profile: "Studio")
                )
            ]
        )[.vision]
        let writing = away?.first { $0.pick == .vision(lens: "Writing") }
        #expect(writing?.refusal == "Not in Studio")
        #expect(writing?.isApplicable == false)
    }

    @Test("every chip greys while KiwiDesk boots, and says so")
    func inertGreysAll() {
        LocalizationManager.shared.select("en")
        let every = items(inert: ViewPickText.starting).values.flatMap { $0 }
        // New Lens… opens Settings, which no boot holds (#2103).
        let all = every.filter { $0.pick != .newLens }
        #expect(every.first { $0.pick == .newLens }?.isApplicable == true)
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { !$0.isApplicable })
        #expect(all.allSatisfy { $0.inertReason == "KiwiDesk is starting" })
        let plain = items(inert: ViewPickText.starting)[.vision]?.first
        #expect(
            plain.map {
                ViewPickText.spoken($0, on: .vision, visionOff: true)
            } == "KiwiVision, off: Default, KiwiDesk is starting"
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
                "core.vision.onChange={[weakself]active,causein"
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
            lensChord: { _ in nil },
            offersNewLens: true,
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
