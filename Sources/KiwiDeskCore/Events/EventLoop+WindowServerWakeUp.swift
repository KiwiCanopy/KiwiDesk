import CoreGraphics
import Foundation

/// WindowServer's window create/destroy as a WAKE-UP for the AX
/// path (#1877): a fresh app's observer may never deliver its
/// first `AXWindowCreated`, leaving the window to the 5 s heal
/// (#1599 measured 0.6–6.3 s). A wake-up only asks the app again
/// through `reconcileOffMain`; the AX list stays the truth.
extension EventLoop {
    /// How long a wake-up waits for the AX path to answer first;
    /// a window it adopted meanwhile, or a popup that never
    /// settled at layer 0, costs no read.
    static let wakeUpGrace: TimeInterval = 0.3

    /// Routes the WindowServer notifications here; called with
    /// the workspace observers, which a test core never registers.
    func startWindowServerWakeUp() {
        SkyLightWindowLifecycle.sink = { [weak self] change, id in
            let owner = Self.windowOwnerPID(id)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.wakeUpGrace
            ) { [weak self] in
                MainActor.assumeIsolated {
                    self?.windowServerChanged(
                        change,
                        id: id,
                        owner: owner,
                        shownNormal: change == .created
                            && Self.isShownNormal(id)
                    )
                }
            }
        }
        let active = SkyLightWindowLifecycle.start()
        onLog(
            "WindowServer window wake-up "
                + (active ? "active" : "unavailable")
        )
    }

    /// One create or destroy, judged after the grace. A create
    /// wakes only an OBSERVED app for a window it still does not
    /// track and WindowServer shows at layer 0 — an unobserved app
    /// is the launch notification's to attach, and its attach
    /// scans; a destroy wakes only the app still tracking it.
    func windowServerChanged(
        _ change: SkyLightWindowLifecycle.Change,
        id: WindowID,
        owner: pid_t?,
        shownNormal: Bool
    ) {
        let pid: pid_t?
        switch change {
        case .created:
            guard shownNormal, let owner, !Self.isOwnProcess(owner),
                observers[owner] != nil,
                elements[owner]?[id] == nil
            else { return }
            pid = owner
        case .destroyed:
            pid = elements.first { $0.value[id] != nil }?.key
        }
        guard let pid else { return }
        onLog("wake-up: w\(id.raw) \(change) unanswered, pid \(pid)")
        reconcileOffMain(pid: pid, app: AppRef(pid: pid))
    }

    /// The process owning `id`, read once from WindowServer.
    nonisolated static func windowOwnerPID(_ id: WindowID) -> pid_t? {
        info(id)?[kCGWindowOwnerPID as String] as? pid_t
    }

    /// Whether WindowServer shows `id` on screen at layer 0.
    nonisolated static func isShownNormal(_ id: WindowID) -> Bool {
        guard let info = info(id) else { return false }
        return info[kCGWindowLayer as String] as? Int == 0
            && info[kCGWindowIsOnscreen as String] as? Bool == true
    }

    private nonisolated static func info(
        _ id: WindowID
    ) -> [String: Any]? {
        (CGWindowListCopyWindowInfo(
            [.optionIncludingWindow],
            CGWindowID(id.raw)
        ) as? [[String: Any]])?.first
    }
}
