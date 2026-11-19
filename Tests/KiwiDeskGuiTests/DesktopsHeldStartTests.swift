import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// With a full-screen Space in front, no Desktop of KiwiHub's
/// screen is shown, and the Desktops side opens on the one the live
/// Spaces hold (#3486). The held Desktop is the second here, so an
/// opening that fell back to the first reds.
@Suite("Desktops side ▸ opening behind a full-screen Space")
struct DesktopsHeldStartTests {
    private func desktop(
        _ label: Int,
        holdsLive: Bool
    ) -> DesktopOverview.Desktop {
        DesktopOverview.Desktop(
            native: UInt64(10 + label),
            label: label,
            number: label,
            isShown: false,
            holdsLive: holdsLive,
            profile: nil,
            spaces: [
                DesktopsStateTests.line("1", []),
                DesktopsStateTests.line("2", [], shown: true),
            ]
        )
    }

    @Test("it opens on the held Desktop's active line")
    func opensOnTheHeldDesktop() {
        let screen = DesktopOverview.Screen(
            display: DisplayID(1),
            name: "Built-in",
            isMain: true,
            isHere: true,
            desktops: [
                desktop(1, holdsLive: false),
                desktop(2, holdsLive: true),
            ]
        )
        let state = DesktopsStateTests.state(
            DesktopOverview(screens: [screen], yours: nil)
        )
        #expect(state.place == DesktopsPlace(screen: 0, desktop: 1, line: 1))
    }
}
