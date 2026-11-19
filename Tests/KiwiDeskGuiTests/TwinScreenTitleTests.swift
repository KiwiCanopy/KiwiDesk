import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Twins macOS numbered ("Twin (2)" left of "Twin (1)") read by
/// position wherever a screen is named for a choice (#3496):
/// KiwiHub's Desktops headings and a Space's Screen menu.
@MainActor
@Suite("Twin screens read by position (#3496)", .serialized)
struct TwinScreenTitleTests {
    private func model(_ displays: [Display]) -> SettingsModel {
        let model = makeTestModel(
            core: makeTestCore(
                configDirectory:
                    testTemporaryDirectory
                    .appendingPathComponent("kiwi-twin-\(UUID().uuidString)")
            )
        )
        for display in displays {
            model.core.state.workspaces.upsertDisplay(display)
        }
        return model
    }

    private func display(_ id: UInt32, _ name: String, x: CGFloat) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: 0, width: 100, height: 100)
        )
    }

    @Test("a Space's Screen menu names twins by position")
    func spaceScreenMenu() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let left = display(2, "Twin (2)", x: 0)
        let right = display(1, "Twin (1)", x: 100)
        let lone = display(3, "Studio (2)", x: 200)
        let model = model([left, right, lone])
        func title(_ display: Display) -> String {
            SpaceScreenChoice.screen(display.fingerprint).title(in: model)
        }
        #expect(title(left) == "Twin (left)")
        #expect(title(right) == "Twin (right)")
        #expect(title(lone) == "Studio (2)")
        #expect(
            SpaceScreenChoice.screen("Gone:10x10").title(in: model)
                == model.screenName("Gone:10x10")
        )
    }

    @Test("a KiwiHub heading names a twin by position")
    func kiwiHubHeading() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        func row(_ position: ScreenNamePosition?) -> DesktopOverview.Screen {
            DesktopOverview.Screen(
                display: DisplayID(1),
                name: "Twin (2)",
                isMain: false,
                isHere: false,
                desktops: [],
                position: position
            )
        }
        #expect(DesktopsSideView.title(row(.left)) == "Twin (left)")
        #expect(DesktopsSideView.title(row(nil)) == "Twin (2)")
    }
}
