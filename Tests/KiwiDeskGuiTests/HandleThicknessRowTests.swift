import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The KiwiShelf card's Handle thickness stepper (#3451): in the
/// Show group between Show and Reveal, greyed with its own reason
/// only while nothing rests as a handle anywhere — no Auto bar, no
/// Pocket handle, no handle over a maximized window.
@Suite("Handle thickness row (#3451)")
struct HandleThicknessRowTests {
    private let key = SettingKey.kiwishelf(.handleThickness)

    /// Every bar and the Pocket Always, the maximized reveal off:
    /// nothing rests as a handle.
    private func nothingRests() -> TilingSettings {
        var settings = TilingSettings()
        settings.setEveryBarVisibility(.always)
        settings.kiwishelf.maximizedVisibility = .hidden
        return settings
    }

    private func reason(_ settings: TilingSettings) -> BarsGates
        .InertReason?
    {
        BarsGates(settings: settings).inertReason(for: key)
    }

    @Test("it sits between Show and Reveal")
    func order() {
        #expect(
            BarsRowOrder.kiwishelfShow == [
                .kiwishelf(.visibility), key, .kiwishelf(.revealStyle),
            ]
        )
        #expect(BarsGates.resolved.contains(key))
        #expect(key.placement.gate == .runtime(.noHandleRests))
    }

    @Test("it greys only while nothing rests as a handle")
    func greysOnlyWithNoHandle() {
        #expect(reason(nothingRests()) == .noHandle)
        var auto = nothingRests()
        auto.spaceBarStyle.visibility = .auto
        #expect(reason(auto) == nil)
        // A stored Hidden bar rests as nothing.
        var hidden = nothingRests()
        hidden.setEveryBarVisibility(.hidden)
        hidden.kiwishelf.maximizedVisibility = .hidden
        #expect(reason(hidden) == .noHandle)
        // The bars' handles over a maximized window.
        var maximized = nothingRests()
        maximized.kiwishelf.maximizedVisibility = .auto
        #expect(reason(maximized) == nil)
    }

    @Test("the Pocket's handle keeps it live")
    func pocketHandleKeepsItLive() throws {
        var settings = nothingRests()
        settings.kiwishelf.pocketVisibility = .auto
        let barEdges = Set(
            LayoutMode.allCases.flatMap {
                settings.barEdges(in: $0).map(\.edge)
            }
        )
        let free = try #require(
            AppBarEdge.allCases.first { !barEdges.contains($0) }
        )
        settings.kiwishelf.pocketEdge = free
        #expect(reason(settings) == nil)
    }

    /// On a bar's edge the Pocket is a section, save in a layout
    /// that maximizes its windows, where it rests nowhere (#2976 ▸
    /// 4): no handle there either.
    @Test("a maximizing layout's Pocket is no handle")
    func maximizingPocketRestsNowhere() {
        var settings = nothingRests()
        settings.kiwishelf.pocketVisibility = .auto
        settings.kiwishelf.pocketEdge = settings.spaceBarStyle.edge
        settings.monocle.maximizeWindows = true
        #expect(reason(settings) == .noHandle)
    }
}
