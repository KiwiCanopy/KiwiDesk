import Foundation
import KiwiDeskCore

/// A drop that keeps KiwiHub open whose moves land after their
/// verbs return (#3208): a window sent to a Desktop no screen shows
/// leaves its line only once macOS reports it gone, after the panel
/// has read the desk again. Until every moved window shows on the
/// target line, or `bound` passes, each window or Desktop event
/// reads the desk once more.
struct DesktopsLanding {
    let ids: Set<WindowID>
    let target: DesktopsTarget
    /// Uptime seconds past which the panel stops waiting.
    let deadline: TimeInterval

    /// How long a drop waits for its moves to land.
    static let bound: TimeInterval = 3

    /// Whether `overview` lists every moved window on the target's
    /// line.
    func landed(in overview: DesktopOverview) -> Bool {
        // A Desktop's native id names it on every screen.
        let line = overview.screens
            .flatMap(\.desktops)
            .filter { $0.native == target.desktop.native }
            .flatMap(\.spaces)
            .first { $0.space == target.space }
        let there = Set(line?.windows.map(\.id) ?? [])
        return ids.isSubset(of: there)
    }

    /// Whether `event` can move a window between lines.
    static func reads(_ event: KiwiNotification) -> Bool {
        switch event {
        case .windowCreated, .windowDestroyed, .windowMovedToSpace,
            .spaceChange, .desktopChange:
            true
        default:
            false
        }
    }
}

extension JumpPanelController {
    /// Waits for a stay-open drop of `ids` onto `target` to land
    /// where the read after it does not yet show it (#3208).
    func awaitLanding(
        _ ids: [WindowID],
        on target: DesktopsTarget,
        model: JumpModel
    ) {
        endLanding()
        guard let overview = model.desktops?.overview else { return }
        let landing = DesktopsLanding(
            ids: Set(ids),
            target: target,
            deadline: ProcessInfo.processInfo.systemUptime
                + DesktopsLanding.bound
        )
        guard !landing.landed(in: overview) else { return }
        landingSink = core.bus.addSink { [weak self, weak model] event, _ in
            guard let self, DesktopsLanding.reads(event) else { return }
            guard let model else { return self.endLanding() }
            self.reread(landing, model: model)
        }
    }

    /// Stops waiting for a drop to land.
    func endLanding() {
        guard let token = landingSink else { return }
        core.bus.removeSink(token)
        landingSink = nil
    }

    /// Reads the desk again, or ends the wait where KiwiHub left the
    /// side or the bound passed, and once the drop shows.
    private func reread(_ landing: DesktopsLanding, model: JumpModel) {
        guard isOpen, model.scope == .desktops,
            ProcessInfo.processInfo.systemUptime < landing.deadline
        else { return endLanding() }
        model.refreshDesktops()
        if let overview = model.desktops?.overview,
            landing.landed(in: overview)
        {
            endLanding()
        }
    }
}
