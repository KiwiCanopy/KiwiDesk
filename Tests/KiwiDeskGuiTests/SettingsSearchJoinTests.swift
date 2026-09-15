import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The census↔catalog join's silent failure shape (#277).
/// `SettingsSearchIndex.row(for:)` takes the FIRST catalog entry
/// carrying a census row's label key, so a second entry under
/// one key resolves every such row to the first declared, and
/// nothing else reds — `SettingsCatalogTests` holds id
/// uniqueness, and keys legitimately recur across instanced
/// drawers.
@Suite("Settings search join")
@MainActor
struct SettingsSearchJoinTests {
    /// No destination declares two catalog entries carrying one
    /// indexed census row's label key — the instanced drawers
    /// share `bars.style`, which no census row carries, so they
    /// pass; a second `drag.border` control would not.
    @Test("one census label key names at most one entry")
    func labelKeysJoinAtMostOneEntry() {
        var checked = 0
        for destination in SettingsDestination.allCases {
            let entries = SettingsCatalog.entries(of: destination)
            let keys = SettingKey.allCases.filter {
                $0.placement.area == destination.area
                    && SettingsSearchIndex.indexes($0)
            }
            for key in keys {
                guard case .key(let label) = key.text.label else {
                    continue
                }
                checked += 1
                let carriers = entries.filter {
                    $0.control.key == label
                }
                #expect(
                    carriers.count <= 1,
                    Comment(
                        rawValue:
                            "\(key.id) resolves onto the first of "
                            + carriers.map(\.control.id)
                            .joined(separator: ", ")
                    )
                )
            }
        }
        #expect(checked > 0)
    }
}
