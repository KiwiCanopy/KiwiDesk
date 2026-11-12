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
    /// runs the pick. A plain drop keeps KiwiHub open on the target
    /// line and shows a window that did not move (#3165); every
    /// other pick closes it first and names one after the close.
    func perform(
        _ action: DesktopsAction,
        in overview: DesktopOverview,
        model: JumpModel
    ) {
        if let refusal = refusal(of: action) {
            model.refuseDesktops(refusal)
            return
        }
        if case .drop(let ids, let target, follow: false) = action {
            let failed = move(ids, to: target, follow: false)
            model.reloadDesktops(selecting: target)
            let gone = Set(failed.map(\.id))
            awaitLanding(
                ids.filter { !gone.contains($0) },
                on: target,
                model: model
            )
            if let words = Self.words(failed, in: overview) {
                model.refuseDesktops(words)
            } else {
                model.onAnnounce(model.desktopsSpoken)
            }
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
        // Spoken only: the refusal sound answers an in-panel
        // refusal alone (`JumpRefusalRowTests`).
        guard let words = Self.words(failed, in: overview) else { return }
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: words, .priority: 90]
        )
    }

    /// What a move left behind says: Core's reason where it gave
    /// one, else that the window did not move.
    private static func words(
        _ failed: [Failure],
        in overview: DesktopOverview
    ) -> String? {
        let words = failed.compactMap { failure -> String? in
            if let reason = failure.reason {
                return DesktopsText.awayRefusal(reason)
            }
            return overview.window(failure.id).map(DesktopsText.notMoved)
        }
        return words.isEmpty ? nil : words.joined(separator: ". ")
    }

    /// What Core refuses for `action` now, in the panel's words.
    private func refusal(of action: DesktopsAction) -> String? {
        // The panel's screen, as the pick below reads it.
        let hub = hubDisplay
        switch action {
        case .moveWindowHere(let id):
            return core.moveHereRefusal(.window(id), on: hub)
                .map(JumpRowText.refusal)
        case .swapWindowHere(let id):
            return core.swapRefusal(.window(id), on: hub)
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
        case .moveYours(let target, _):
            return !target.desktop.isShown && target.desktop.number == nil
                ? DesktopsText.refusal(.unreachable) : nil
        case .drop(let ids, let target, let follow):
            if !target.desktop.isShown, target.desktop.number == nil {
                return DesktopsText.refusal(.unreachable)
            }
            // A follow's window is asked before the switch, so its
            // refusal stays in the panel (#3171).
            guard follow, let first = ids.first else { return nil }
            return core.awayMoveRefusal(
                first,
                toDesktop: target.desktop.native,
                follow: true
            ).map(DesktopsText.awayRefusal)
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
        case .jumpWindow(let id), .swapWindowHere(let id),
            .moveWindowHere(let id):
            return overview.window(id)?.pid
        case .jump(let target):
            return target.lastFocused.flatMap(overview.window)?.pid
        case .drop(let ids, _, follow: true):
            return ids.first.flatMap(overview.window)?.pid
        default:
            return nil
        }
    }

    /// A window a move left where it was, with Core's reason where
    /// it gave one.
    struct Failure {
        let id: WindowID
        let reason: AwayMoveRefusal?
    }

    /// Runs `action`; the windows a move refused.
    private func run(
        _ action: DesktopsAction,
        in overview: DesktopOverview
    ) -> [Failure] {
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
            return moved ? [] : [Failure(id: yours, reason: nil)]
        case .jumpWindow(let id):
            core.jump(to: .window(id))
        case .moveWindowHere(let id):
            _ = core.moveHere(.window(id), on: hubDisplay)
        case .swapWindowHere(let id):
            core.swapHere(.window(id), on: hubDisplay)
        case .drop(let ids, let target, let follow):
            return move(ids, to: target, follow: follow)
        }
        return []
    }

    /// One move per window in pick order; a follow goes last, on
    /// the first-picked window, so the others leave before the
    /// Desktop switches and focus lands on it. A window on a hidden
    /// Desktop is asked first, so its refusal keeps Core's reason.
    private func move(
        _ ids: [WindowID],
        to target: DesktopsTarget,
        follow: Bool
    ) -> [Failure] {
        guard let first = ids.first else { return [] }
        let rest = follow ? Array(ids.dropFirst()) : ids
        var failed = rest.compactMap { move($0, to: target, follow: false) }
        if follow, let failure = move(first, to: target, follow: true) {
            failed.insert(failure, at: 0)
        }
        return failed
    }

    private func move(
        _ id: WindowID,
        to target: DesktopsTarget,
        follow: Bool
    ) -> Failure? {
        let native = target.desktop.native
        if let reason = core.awayMoveRefusal(
            id,
            toDesktop: native,
            follow: follow
        ) {
            return Failure(id: id, reason: reason)
        }
        let moved = core.overviewMove(
            id,
            into: target.space,
            onDesktop: native,
            follow: follow
        )
        return moved ? nil : Failure(id: id, reason: nil)
    }
}
