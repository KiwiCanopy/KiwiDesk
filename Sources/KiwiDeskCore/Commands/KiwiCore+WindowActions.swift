import ApplicationServices
import Foundation

/// The AX presses behind `new_window` and `close_window` — the
/// machine's half, seamed so a test states what the app answered
/// (`makeTestCore` pins both inert). Each walk blocks on another
/// app, so it runs off the main actor and answers on it.
@MainActor
struct WindowActionSeams {
    /// Answers on the main actor whether the press happened.
    typealias Done = @MainActor (Bool) -> Void

    /// Presses `pid`'s New Window row.
    var newWindow: @MainActor (pid_t, @escaping Done) -> Void =
        Self.pressNewWindow

    /// Presses the window's close button.
    var close: @MainActor (AXUIElement, @escaping Done) -> Void =
        Self.pressClose

    private static func pressNewWindow(
        _ pid: pid_t,
        _ done: @escaping Done
    ) {
        offMain(done) { AXWindowActions.pressNewWindow(pid: pid) }
    }

    private static func pressClose(
        _ element: AXUIElement,
        _ done: @escaping Done
    ) {
        nonisolated(unsafe) let window = element
        offMain(done) { AXWindowActions.pressClose(window) }
    }

    private static func offMain(
        _ done: @escaping Done,
        _ work: @escaping @Sendable () -> Bool
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let pressed = work()
            Task { @MainActor in done(pressed) }
        }
    }
}

/// `new_window` and `close_window` (#1518): the window rows' two
/// AX verbs, public so the menu, Lua and the CLI take one path
/// (bars.md). What state can refuse, they refuse at once; what
/// only the AX walk can tell is cued when it answers, since
/// `execute` replies before the walk returns.
extension KiwiCore {
    func newWindow(_ args: [JSONValue]) -> CommandResponse {
        let window: ManagedWindow
        switch actionTarget("new_window", args) {
        case .failure(let refusal): return refusal.response
        case .success(let target): window = target
        }
        // A window its App Rule files elsewhere is followed there,
        // as an Open or Focus launch is (#1599).
        if let bundle = window.appBundleID { oweLaunchFollow(bundle) }
        openOrFocus.activate(window.pid)
        windowActions.newWindow(window.pid) { [weak self] pressed in
            guard !pressed, let self else { return }
            // Nothing opened, so nothing is owed (#1599).
            if let bundle = window.appBundleID,
                launchFollow.owed() == bundle
            {
                launchFollow.forget(keeping: bundle)
            }
            cueWindowAction(
                .noNewWindow(app: window.appName),
                on: window.id
            )
        }
        return .ok()
    }

    func closeWindow(_ args: [JSONValue]) -> CommandResponse {
        let window: ManagedWindow
        switch actionTarget("close_window", args) {
        case .failure(let refusal): return refusal.response
        case .success(let target): window = target
        }
        guard let element = eventLoop.element(for: window.id) else {
            return .fail("window \(window.id.raw) has no AX element")
        }
        windowActions.close(element) { [weak self] pressed in
            guard !pressed else { return }
            guard let self else { return }
            cueWindowAction(
                .noCloseButton(
                    window: String(windowTitle(window.id).prefix(40))
                ),
                on: window.id
            )
        }
        return .ok()
    }

    /// The named or focused window, never one of KiwiDesk's own:
    /// its Settings window closes itself, and a walk of our own
    /// menu from a background queue deadlocks the main actor.
    private func actionTarget(
        _ command: String,
        _ args: [JSONValue]
    ) -> Result<ManagedWindow, ActionRefusal> {
        switch commandTarget(command, args) {
        case .refused(let response):
            return .failure(ActionRefusal(response: response))
        case .window(let id):
            // `commandTarget` answers only a tracked id.
            guard let window = state.windows[id],
                !EventLoop.isOwnProcess(window.pid)
            else {
                return .failure(
                    ActionRefusal(
                        response: .fail(
                            "\(command) does not act on KiwiDesk's "
                                + "own windows"
                        )
                    )
                )
            }
            return .success(window)
        }
    }

    /// Flashes the refusal where `cueWindow(for:)` says; the
    /// sentence names its subject, so it reads right on either.
    /// Drawn without sound: it lands after the walk, long after
    /// any hotkey fire that asked, and the sound is a fire's.
    func cueWindowAction(
        _ refusal: WindowActionRefusal,
        on target: WindowID
    ) {
        onLog("\(refusal.logReason): w\(target.raw)")
        guard let window = cueWindow(for: target) else { return }
        flashRefusalPill(
            window,
            text: refusal.sentence,
            symbol: refusal.pillSymbol
        )
    }

    /// The window a refusal about `target` draws on: `target`
    /// where it is drawn — a shown Space, its pill's centre on a
    /// screen, which a park or a scrolled-out slot is not — else
    /// the focused window, which the user is looking at.
    func cueWindow(for target: WindowID) -> WindowID? {
        let shown =
            state.workspaces.space(of: target).map {
                state.workspaces.visibleSpaces.contains($0)
            } == true
        let onScreen =
            refusalPillFrame(target).map { frame in
                tiler.allScreenBounds().contains {
                    $0.contains(CGPoint(x: frame.midX, y: frame.midY))
                }
            } == true
        return shown && onScreen ? target : focusedWindowID
    }
}

/// A refusal `Result` can carry.
struct ActionRefusal: Error {
    let response: CommandResponse
}
