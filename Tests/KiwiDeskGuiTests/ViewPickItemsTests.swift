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
        inert: Bool = false
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

    @Test("every chip greys while KiwiDesk boots")
    func inertGreysAll() {
        LocalizationManager.shared.select("en")
        let all = items(inert: true).values.flatMap { $0 }
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { !$0.isApplicable })
    }

    @Test("the layouts grey where no Space is under the pointer")
    func noSpaceGreysLayouts() {
        LocalizationManager.shared.select("en")
        let lines = JumpPanelController.items(
            layout: nil,
            profiles: ("Laptop", ["Laptop", "Studio"], []),
            visionOn: false,
            visionChord: nil,
            inert: false
        )
        #expect(lines[.layout]?.allSatisfy { !$0.isApplicable } == true)
        #expect(lines[.vision]?.allSatisfy(\.isApplicable) == true)
    }
}
