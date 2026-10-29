import Testing

@testable import KiwiDesk

/// Turning `LookGallery.isLive` on owes each gallery door its
/// `SettingKey` census row (#1740 ▸ Launch together), so the flip
/// reds until the rows exist. A door the switch gates joins
/// `doors` in the change that draws it.
@Suite("Looks gallery doors")
@MainActor
struct LookGalleryCensusTests {
    static let doors = ["(action) look.browse", "(action) look.share"]

    @Test("a live gallery has a census row per door")
    func liveDoorsHaveRows() {
        guard LookGallery.isLive else { return }
        let ids = Set(SettingKey.allCases.map(\.id))
        for door in Self.doors {
            #expect(ids.contains(door), "no census row for \(door)")
        }
    }
}
