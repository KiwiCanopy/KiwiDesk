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

    /// The model reads the roster on reload; the add button greys
    /// where no profile file is live.
    @Test("a reload reads the temporary Spaces, greyed with no profile")
    func reloadReadsTheRoster() {
        let core = makeTestCore()
        core.execute("create_space", args: [.string("7")])
        let model = makeTestModel(core: core)
        model.reload()
        let row = model.liveOnlySpaces.first { $0.id == SpaceID(7) }
        #expect(row?.isTemporary == true)
        #expect(row?.canAdd == false)
    }
}
