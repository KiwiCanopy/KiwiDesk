import Testing

@testable import KiwiDesk

/// Each gallery door owes its `SettingKey` census row (#1740 ▸
/// Launch together), on the Looks shelf's at-rest tier, labelled by
/// the key the door draws. A further door joins `doors` in the
/// change that draws it.
@Suite("Looks gallery doors")
@MainActor
struct LookGalleryCensusTests {
    static let doors: [(row: String, label: String)] = [
        ("(action) look.browse", "looks.browse"),
        ("(action) look.share", "looks.share"),
    ]

    @Test("every gallery door has a census row on the Looks shelf")
    func doorsHaveRows() {
        for door in Self.doors {
            let key = SettingKey.allCases.first { $0.id == door.row }
            guard let key else {
                Issue.record("no census row for \(door.row)")
                continue
            }
            #expect(
                key.placement == .row(.coloursAndMotion, .looks, .atRest),
                "\(door.row) is off the shelf's at-rest tier"
            )
            #expect(
                key.text == .text(door.label),
                "\(door.row) is not labelled \(door.label)"
            )
        }
    }
}
