import Foundation

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The one way a GUI test builds a `SettingsModel` (#678
/// turn 9): both `UserDefaults` seams get a scratch domain, so
/// a suite that drives the model dirty→clean (which retires the
/// first-run banner) or flips the Settings mode never writes
/// the developer's real defaults. Same omission class as
/// `makeTestCore` — every forgotten call site re-enables a
/// process-global write — so `MachineTouchTests` pins every
/// `SettingsModel(` in this tree to this file. Its own file,
/// not `TestCore.swift`: that file's twin lives in the Core
/// target, which cannot see `SettingsModel`, and the twins are
/// pinned identical.
///
/// Pass `defaults:` to keep a handle for asserting persistence;
/// omitted, a fresh scratch domain is minted per model.
@MainActor
func makeTestModel(
    core: KiwiCore? = nil,
    defaults: UserDefaults? = nil
) -> SettingsModel {
    let domain =
        defaults
        ?? {
            let name =
                "kiwi-test-defaults-\(UUID().uuidString)"
            let scratch = UserDefaults(suiteName: name)!
            scratch.removePersistentDomain(forName: name)
            return scratch
        }()
    return SettingsModel(
        core: core ?? makeTestCore(),
        modeDefaults: domain,
        firstRunDefaults: domain
    )
}
