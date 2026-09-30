import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Settings ▸ Spaces' view-only rows (#1790): the Spaces the profile
/// does not hold reach the model from Core, and the pointer that
/// explains a greyed add button places its link.
@Suite("Live-only Space rows (#1790)", .serialized)
@MainActor
struct LiveOnlySpaceRowTests {
    @Test("the no-profile pointer places its link")
    func noProfileProsePlacesItsLink() {
        #expect(
            SpacesSection.noProfileProse.contains(
                CrossReferenceRow.linkSlot
            )
        )
    }

    /// The model reads the roster on reload, and a temporary row's
    /// add button is live where a profile file is.
    @Test("a reload reads the temporary Spaces")
    func reloadReadsTheRoster() throws {
        let core = makeTestCore()
        core.execute("save_profile", args: [.string("p")])
        core.execute("create_space", args: [.string("7")])
        let model = makeTestModel(core: core)
        model.reload()
        let row = model.liveOnlySpaces.first { $0.id == SpaceID(7) }
        #expect(row?.isTemporary == true)
        #expect(row?.canAdd == true)
    }
}
