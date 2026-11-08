import AppKit
import KiwiDeskCore

/// KiwiHub's Desktops side (#1229): which screen it reads from and
/// what a pick does. Moves go through Core's overview doors, which
/// pick the verb from a fresh reading of the Desktops; Move here
/// and Swap here ask Core at the press, as the Windows side does
/// (gui.md ▸ A KiwiHub pick asks Core at the press).
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
            guard let self, let model,
                let overview = model.desktops?.overview
            else { return }
            self.perform(action, in: overview, model: model)
        }
        // ⌘, opens Profiles, whose Desktops card binds them.
        model.onDesktopsSettings = { [weak self] in
            guard let self, self.dismiss(distrusting: false) else { return }
            self.core.barMenuHooks.openSettings(.profiles)
        }
    }

    /// Refuses in the panel what Core refuses at the press; else
    /// closes it and runs the pick. A window that did not move is
    /// named after the close.
    func perform(
        _ action: DesktopsAction,
        in overview: DesktopOverview,
        model: JumpModel
    ) {
        if let refusal = refusal(of: action) {
            model.onRefuse(refusal)
            return
        }
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

    /// What Core refuses for `action` now, in the panel's words.
    private func refusal(of action: DesktopsAction) -> String? {
        switch action {
        case .moveHere(let id):
            return core.moveHereRefusal(.window(id), on: hubDisplay)
                .map(JumpRowText.refusal)
        case .swapHere(let id):
            return core.swapRefusal(.window(id), on: hubDisplay)
                .map(JumpRowText.refusal)
        case .jumpDesktop(let desktop), .moveYoursToDesktop(let desktop):
            return desktop.number == nil
                ? DesktopsText.refusal(.unreachable) : nil
        // A hidden Desktop's Space is reached by its last-focused
        // window, which needs no number.
        case .jump(let target):
            return !target.desktop.isShown && target.desktop.number == nil
                && target.lastFocused == nil
                ? DesktopsText.refusal(.unreachable) : nil
        case .moveYours(let target, _), .drop(_, let target, _):
            return !target.desktop.isShown && target.desktop.number == nil
                ? DesktopsText.refusal(.unreachable) : nil
        case .jumpWindow:
            return nil
        }
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
            core.overviewJump(
                to: target.space,
                onDesktop: target.desktop.native,
                lastFocused: target.lastFocused
            )
        case .moveYours(let target, let follow):
            guard let yours = overview.yours else { return [] }
            return move([yours], to: target, follow: follow)
        case .jumpDesktop(let desktop):
            core.overviewJump(toDesktop: desktop.native)
        case .moveYoursToDesktop(let desktop):
            guard let yours = overview.yours else { return [] }
            let moved = core.overviewMove(yours, toDesktop: desktop.native)
            return moved ? [] : [yours]
        case .jumpWindow(let id):
            core.jump(to: .window(id))
        case .moveHere(let id):
            _ = core.moveHere(.window(id), on: hubDisplay)
        case .swapHere(let id):
            core.swapHere(.window(id), on: hubDisplay)
        case .drop(let ids, let target, let follow):
            return move(ids, to: target, follow: follow)
        }
        return []
    }

    /// One move per window in pick order; a follow goes last, on
    /// the first-picked window, so the others leave before the
    /// Desktop switches and focus lands on it.
    private func move(
        _ ids: [WindowID],
        to target: DesktopsTarget,
        follow: Bool
    ) -> [WindowID] {
        guard let first = ids.first else { return [] }
        let rest = follow ? Array(ids.dropFirst()) : ids
        var failed = rest.filter {
            !core.overviewMove(
                $0,
                into: target.space,
                onDesktop: target.desktop.native,
                follow: false
            )
        }
        if follow,
            !core.overviewMove(
                first,
                into: target.space,
                onDesktop: target.desktop.native,
                follow: true
            )
        {
            failed.insert(first, at: 0)
        }
        return failed
    }
}
