import AppKit
import KiwiDeskCore

/// KiwiHub's Desktops side (#1229): which screen it reads from and
/// what a pick does. Every move goes through the verbs a binding
/// runs — `move_to_space` on a Desktop its screen shows,
/// `move_to_desktop` with its Space on one it does not (#2888) —
/// naming the window, so no pick acts on a focus it did not mean.
extension JumpPanelController {
    func wireDesktops(_ model: JumpModel) {
        model.loadDesktops = { [weak self] in
            guard let self else {
                return DesktopOverview(screens: [], yours: nil)
            }
            return self.core.desktopOverview(on: self.hubDisplay)
        }
        model.loadIcons = { Self.icons(for: $0) }
        model.onDesktopsAction = { [weak self, weak model] action in
            guard let self, let overview = model?.desktops?.overview
            else { return }
            self.perform(action, in: overview)
        }
    }

    /// Closes the panel, then runs the pick; a window that did not
    /// move is named after the close.
    func perform(_ action: DesktopsAction, in overview: DesktopOverview) {
        let own = ProcessInfo.processInfo.processIdentifier
        let pid = Self.landingPid(action, in: overview)
        guard
            dismiss(
                distrusting: pid.map {
                    Self.distrustsHandoff(pick: $0, own: own)
                } ?? false
            )
        else { return }
        let failed = run(action, in: overview)
        guard !failed.isEmpty else { return }
        core.soundPanelRefusal()
        let words = failed.compactMap(overview.window)
            .map(DesktopsText.notMoved)
            .joined(separator: ". ")
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: words, .priority: 90]
        )
    }

    /// The app a pick leaves in front, where it names a window.
    private static func landingPid(
        _ action: DesktopsAction,
        in overview: DesktopOverview
    ) -> pid_t? {
        switch action {
        case .jumpWindow(let id), .swapHere(let id), .moveHere(let id):
            return overview.window(id)?.pid
        case .jump(let target):
            return target.lastFocused.flatMap(overview.window)?.pid
        case .drop(let ids, _, follow: true):
            return ids.first.flatMap(overview.window)?.pid
        default:
            return nil
        }
    }

    /// Runs `action`; the windows a move refused.
    private func run(
        _ action: DesktopsAction,
        in overview: DesktopOverview
    ) -> [WindowID] {
        switch action {
        case .jump(let target):
            jump(to: target)
        case .moveYours(let target, let follow):
            guard let yours = overview.yours else { return [] }
            return move(yours, to: target, follow: follow) ? [] : [yours]
        case .jumpDesktop(let desktop):
            if let number = desktop.number {
                _ = send(
                    "focus_desktop",
                    args: [.number(Double(number))]
                )
            }
        case .moveYoursToDesktop(let desktop):
            guard let yours = overview.yours, let number = desktop.number
            else { return [] }
            let response = send(
                "move_to_desktop",
                args: [.number(Double(number)), .null, Self.arg(yours)]
            )
            return response ? [] : [yours]
        case .jumpWindow(let id):
            core.jump(to: .window(id))
        case .moveHere(let id):
            _ = core.moveHere(.window(id), on: hubDisplay)
        case .swapHere(let id):
            core.swapHere(.window(id), on: hubDisplay)
        case .drop(let ids, let target, let follow):
            // One move per window in pick order; the first-picked
            // takes the follow, so focus lands on it.
            return ids.enumerated().compactMap { index, id in
                move(id, to: target, follow: follow && index == 0) ? nil : id
            }
        }
        return []
    }

    /// The Space on its Desktop: the shown one directly, a hidden
    /// one's last-focused window, else the Desktop.
    private func jump(to target: DesktopsTarget) {
        if target.desktop.isShown {
            _ = send("focus_space", args: [.string(target.space.raw)])
        } else if let window = target.lastFocused {
            core.jump(to: .window(window))
        } else if let number = target.desktop.number {
            _ = send("focus_desktop", args: [.number(Double(number))])
        }
    }

    /// Moves `window` into `target`'s Space; whether it went.
    private func move(
        _ window: WindowID,
        to target: DesktopsTarget,
        follow: Bool
    ) -> Bool {
        let space = JSONValue.string(target.space.raw)
        if target.desktop.isShown {
            let verb = follow ? "move_to_space_and_follow" : "move_to_space"
            return send(verb, args: [space, Self.arg(window)])
        }
        guard let number = target.desktop.number else { return false }
        let verb = follow ? "move_to_desktop_and_follow" : "move_to_desktop"
        return send(
            verb,
            args: [.number(Double(number)), space, Self.arg(window)]
        )
    }

    /// One verb, inside the user motion scope (#804); whether it
    /// ran. Jump, Move here and Swap here open their own.
    @discardableResult
    private func send(_ verb: String, args: [JSONValue]) -> Bool {
        core.withUserMotion { core.execute(verb, args: args) }.isSuccess
    }

    private static func arg(_ window: WindowID) -> JSONValue {
        .number(Double(window.raw))
    }
}
