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
            profileID: .legacy(name: name),
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

    /// `summary` saved in the model's core as a profile file — so
    /// Core resolves a binding to it as the app would (#2324) —
    /// and listed on the model.
    static func add(_ summary: ProfileSummary, to model: SettingsModel) {
        _ = try? model.core.profiles.write(
            Profile(
                id: summary.profileID,
                name: summary.name,
                monitorSets: [
                    MonitorSet(
                        monitors: (1...summary.count).map {
                            "\(summary.name)\($0):100x100"
                        }
                    )
                ],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        model.profileSummaries.append(summary)
    }

    /// A card over a model with the fixture's profiles, one live
    /// Desktop on "Built-in".
    static func makeCard() -> (DesktopsGroup, SettingsModel) {
        let model = makeTestModel(
            core: makeTestCore(
                configDirectory:
                    testTemporaryDirectory
                    .appendingPathComponent(
                        "kiwi-group-\(UUID().uuidString)"
                    )
            )
        )
        for summary in profiles { add(summary, to: model) }
        model.mainDesktops = [1]
        model.desktopKeys = [1: live]
        model.presentDesktopKeys = [live, .number(1)]
        model.desktopScreens = [live: "Built-in"]
        return (DesktopsGroup(model: model), model)
    }
}
