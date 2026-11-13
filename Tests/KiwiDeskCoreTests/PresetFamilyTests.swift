import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The preset family (#3294, owner rulings 2026-11-13): Developer,
/// Focus and Studio across counts, Dashboard at two, Developer the
/// fallback at each; slots widest first; at most three Spaces a
/// screen on a multi-screen desk.
@Suite("Preset family (#3294)")
struct PresetFamilyTests {
    private func names(_ count: Int) -> [String] {
        StandardProfiles.workflows.filter { $0.screenCount == count }
            .map(\.name)
    }

    @Test("each count offers the ruled family")
    func familyPerCount() {
        #expect(names(1) == ["Developer", "Focus"])
        #expect(names(2) == ["Developer", "Dashboard", "Focus"])
        #expect(names(3) == ["Developer", "Studio", "Focus"])
        #expect(names(4) == ["Developer", "Studio"])
        #expect(StandardProfiles.largestCount == 4)
    }

    @Test("Developer is every count's fallback")
    func developerIsStandard() {
        for count in 1...4 {
            #expect(StandardProfiles.standard(for: count)?.name == "Developer")
            #expect(
                StandardProfiles.workflows.filter {
                    $0.screenCount == count && $0.isStandard
                }.count == 1
            )
        }
        // A larger desk falls back to the largest plan.
        #expect(StandardProfiles.standard(for: 6)?.screenCount == 4)
    }

    @Test("no screen holds more than three Spaces past one screen")
    func threeAScreen() {
        for layout in StandardProfiles.workflows
        where layout.screenCount > 1 {
            for screen in 0..<layout.screenCount {
                #expect(
                    layout.spaces(
                        onScreen: screen,
                        screens: layout.screenCount
                    ).count <= 3,
                    "\(layout.name) puts too many on \(screen)"
                )
            }
        }
    }

    @Test("a larger desk is offered the 4-screen presets")
    func largerDeskOffersFour() {
        let sizes = Array(
            repeating: CGSize(width: 2560, height: 1440),
            count: 5
        )
        let offered = StandardProfiles.layouts(for: 5, sizes: sizes)
        #expect(offered.first?.starterTitle != nil)
        #expect(
            offered.dropFirst().map(\.name) == ["Developer", "Studio"]
        )
        #expect(offered.dropFirst().allSatisfy { $0.screenCount == 4 })
    }

    private func display(
        _ id: UInt32,
        x: CGFloat,
        width: CGFloat
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: "S\(id)",
            frame: CGRect(x: x, y: 0, width: width, height: 1000)
        )
    }

    /// Slots go widest first, never main first: a laptop beside a
    /// wider screen takes the small slot even when it is main.
    @Test("slots go widest first, whatever is main")
    func widestTakesTheBigSlot() throws {
        let laptop = display(1, x: 0, width: 1512)
        let wide = display(2, x: 1512, width: 2560)
        let composed = try #require(
            ProfileComposition.compose(
                layout: StandardProfiles.developer2,
                displays: [laptop, wide],
                mainID: laptop.id
            )
        )
        for space in ["1", "2", "3"] {
            #expect(composed.assignment[SpaceID(space)] == wide.id)
        }
        for space in ["4", "5", "6"] {
            #expect(composed.assignment[SpaceID(space)] == laptop.id)
        }
        // Positional order for a starter stays main first.
        #expect(
            ProfileComposition.slotOrder([laptop, wide], byWidth: false)
                .map(\.id) == [laptop.id, wide.id]
        )
        // Ties keep positional order.
        let twin = display(3, x: 4072, width: 2560)
        #expect(
            ProfileComposition.slotOrder(
                [laptop, wide, twin],
                byWidth: true
            ).map(\.id) == [wide.id, twin.id, laptop.id]
        )
    }

    @Test("Studio's fourth screen is Grid on a laptop, Stack else")
    func studioFourthByShape() {
        let studio = StandardProfiles.studio4
        #expect(studio.mode(of: "8", on: .laptop) == .grid)
        #expect(studio.mode(of: "8", on: .desktop) == .grid)
        #expect(studio.mode(of: "8", on: .ultrawide) == .stack)
        #expect(studio.mode(of: "8", on: .pivoted) == .stack)
        #expect(studio.mode(of: "8", on: nil) == .stack)
    }

    /// A session snapshot written while a retired Standard was live
    /// still decodes, and the held Space stays where it is: no
    /// arrangement by that name comes back to take it home.
    @Test("a retired Standard's name still decodes")
    func retiredStandardDecodes() throws {
        let json = Data(
            #"{"kind":"standard","name":"Command Center"}"#.utf8
        )
        let arrangement = try JSONDecoder().decode(
            HeldOrigin.Arrangement.self,
            from: json
        )
        #expect(arrangement == .standard("Command Center"))
        #expect(
            !StandardProfiles.workflows.contains {
                $0.name == "Command Center"
            }
        )
    }

    /// …and a Space it held stays held under whatever is live now.
    @Test("a retired Standard's held Space stays held")
    @MainActor func retiredStandardStaysHeld() {
        let core = makeTestCore()
        let screen = display(1, x: 0, width: 2560)
        core.state.workspaces.upsertDisplay(screen)
        let origin = HeldOrigin(
            name: "5",
            screen: screen.fingerprint,
            icon: nil,
            arrangement: .standard("Command Center")
        )
        #expect(
            !core.returnsHome(
                origin,
                declared: ["5"],
                into: .standard("Developer")
            )
        )
    }
}
