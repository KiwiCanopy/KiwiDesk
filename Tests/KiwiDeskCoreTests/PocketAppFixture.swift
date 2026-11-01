import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A core for `pocket_app` (#2612): one tracked window of another
/// app focused, the machine's launch and New Window seams recorded,
/// and the app's Shortcuts row installed where `row` says.
@MainActor
final class PocketAppFixture {
    static let app = "app.test"
    static let pid: pid_t = 900_077
    let core: KiwiCore
    var opened: [String] = []
    var pressed: [pid_t] = []
    var running: pid_t?
    var visible = 0
    var pressAnswers = true

    init(row: Bool = true, appRule: SpaceID? = nil) {
        core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-app-\(UUID().uuidString)"
                )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 900_001,
                    appName: "Other",
                    frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                )
            )
        )
        core.state.apply(.windowFocused(WindowID(1)))
        if let appRule { core.state.appRules[Self.app] = appRule }
        core.openOrFocus.openApp = { [unowned self] id, _ in
            guard id == Self.app else { return false }
            opened.append(id)
            return true
        }
        core.openOrFocus.runningAppPID = { [unowned self] id in
            id == Self.app ? running : nil
        }
        core.openOrFocus.census = { [unowned self] _ in
            .init(visible: visible, minimized: [])
        }
        core.openOrFocus.activate = { _ in }
        core.windowActions.newWindow = { [unowned self] pid, done in
            pressed.append(pid)
            done(pressAnswers)
        }
        if row { installRow(true) }
    }

    /// Installs or drops the app's Pocket key row, as a bindings
    /// install does.
    func installRow(_ present: Bool) {
        let bindings =
            present
            ? [
                KeyBinding(
                    combo: "ctrl+alt+t",
                    lua: PocketAppLuaArg.call(Self.app),
                    kind: .navigation
                )
            ] : []
        core.installedKeybindings = .structured(
            [KeyLayer(name: KeyLayer.defaultName, bindings: bindings)],
            profile: nil,
            skipped: []
        )
        core.reconcilePocketKeys()
    }

    /// The app's Pocket key pressed, or `bundleID`'s.
    @discardableResult
    func press(_ bundleID: String = app) -> CommandResponse {
        core.execute("pocket_app", args: [.string(bundleID)])
    }

    /// The app's window arriving.
    func arrive(_ id: UInt32) {
        core.eventLoop.onEvent(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: Self.pid,
                    appName: "App",
                    appBundleID: Self.app,
                    frame: CGRect(x: 200, y: 200, width: 500, height: 300)
                )
            )
        )
    }
}
