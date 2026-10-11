import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// `draftMonitorSets`' two fallbacks (#1948): with no stored
/// profile under edit, the LOADED profile's saved sets answer, and
/// with neither, the connected screens do. `ScreenEdgeRowsTests`
/// edits a stored profile throughout, so it reaches neither.
@MainActor
@Suite("Per screen rows: the draft's screens fall back (#1948)")
struct ScreenEdgeRowsFallbackTests {
    private let main = Display(
        id: DisplayID(1),
        name: "Color LCD",
        frame: CGRect(x: 0, y: 0, width: 1728, height: 1117)
    )
    private let dell = Display(
        id: DisplayID(2),
        name: "DELL U2720Q",
        frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440)
    )
    /// In the loaded profile's set only, never connected: a row for
    /// it can come from that profile and nowhere else.
    private let absent = "Acer X32:3840x2160"

    /// A live-target draft on the main screen and a DELL, with a
    /// saved "Desk" whose page lists them and the absent Acer.
    private func model() -> SettingsModel {
        let model = makeTestModel()
        let core = model.core
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(main)
        core.state.workspaces.upsertDisplay(dell)
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                count: 3,
                sets: [[main.fingerprint, dell.fingerprint, absent]],
                isDefault: false,
                matchesLive: false,
                matchesConnectedCount: false,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        model.target = .live
        return model
    }

    @Test("the loaded profile's sets answer the live draft")
    func loadedProfileAnswers() throws {
        let model = model()
        let core = model.core
        try core.profiles.save(
            Profile(
                name: "Desk",
                monitorSets: [
                    MonitorSet(
                        monitors: [main.fingerprint, dell.fingerprint]
                    )
                ],
                spaces: [SpaceID("1")],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        _ = core.execute("load_profile", args: [.string("Desk")])
        #expect(core.profiles.currentName == "Desk")
        #expect(model.editingProfile == nil)
        let rows = model.screenEdgeRows(\.spaceBarStyle).map(\.id)
        #expect(rows.contains(absent), "rows: \(rows)")
    }

    @Test("with no profile loaded, the connected screens answer")
    func connectedScreensAnswer() {
        let model = model()
        #expect(model.core.profiles.currentName == nil)
        let rows = Set(model.screenEdgeRows(\.spaceBarStyle).map(\.id))
        #expect(rows == [main.fingerprint, dell.fingerprint])
        #expect(model.offersScreenEdges(\.spaceBarStyle))
    }
}
