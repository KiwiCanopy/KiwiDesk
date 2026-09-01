import Foundation

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The one way a GUI test builds a `SettingsModel` (#678
/// turn 9): the `preferences` seam gets a scratch domain, so a
/// suite that drives the model dirty→clean (which retires the
/// first-run banner), flips the Settings mode or touches the
/// appearance never writes the developer's real defaults.
/// Same omission class as
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
    let model = SettingsModel(
        core: core ?? makeTestCore(),
        preferences: domain
    )
    // #1105: never read the host's com.apple.symbolichotkeys —
    // nil answers mean shipped defaults, so verdicts here are
    // machine-independent. A suite testing the live-state seam
    // overrides `readSymbolicHotkey` per scenario.
    model.readSymbolicHotkey = { _ in nil }
    // #1145: pin the bridge capability FALSE, both mirrors — an
    // earlier bridge suite's `classResolverOverride` can leave
    // `WMBridge.isAvailable`'s process cache true, so the init's
    // own read is order-dependent in a full run. A suite testing
    // the gated surfaces sets both true and resets.
    model.canDriveDesktops = false
    SettingsSearchIndex.canDriveDesktops = false
    return model
}
