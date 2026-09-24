import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Desktops-card fixture the #1436 suites share: two keys,
/// one live and one gone, and three saved profiles of three
/// screen counts.
@MainActor
enum DesktopBindingFixture {
    static let live = DesktopKey.identity(DesktopIdentity(raw: "LIVE"))
    static let gone = DesktopKey.identity(DesktopIdentity(raw: "GONE"))

    static func summary(_ name: String, count: Int) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: count,
            sets: [],
            isDefault: false,
            matchesLive: false,
            matchesConnectedCount: false,
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    static var profiles: [ProfileSummary] {
        [
            summary("Dual", count: 2),
            summary("Laptop", count: 1),
            summary("Triple", count: 3),
        ]
    }

    /// A card over a model with the fixture's profiles, one live
    /// Desktop on "Built-in".
    static func makeCard() -> (DesktopsGroup, SettingsModel) {
        let model = makeTestModel(
            core: makeTestCore(
                configDirectory: FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "kiwi-group-\(UUID().uuidString)"
                    )
            )
        )
        model.profileSummaries = profiles
        model.mainDesktops = [1]
        model.desktopKeys = [1: live]
        model.presentDesktopKeys = [live, .number(1)]
        model.desktopScreens = [live: "Built-in"]
        return (DesktopsGroup(model: model), model)
    }
}
