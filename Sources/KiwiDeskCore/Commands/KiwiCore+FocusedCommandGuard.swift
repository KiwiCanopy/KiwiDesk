import Foundation

extension KiwiCore {
    /// Fail-closed preflight for implicit-focused commands (#292).
    /// Returns a failed `CommandResponse` — blocking the command —
    /// when the command acts on the focused window but the OS
    /// foreground is not that managed window. Returns `nil`
    /// (allow) otherwise. The one mutation it may make: a fresh
    /// wake heal (#1130) re-seeds state focus from the frontmost.
    ///
    /// The guard is inert until `frontmostPIDProvider` is wired
    /// (`start()` installs it; unit tests leave it `nil`), so it
    /// never touches config setters, `focus_space`, spawns, profile
    /// ops, reads, or explicit-id App Bar actions — only the
    /// commands `FocusedCommandPolicy` classifies as focused.
    ///
    /// Foreground ownership requires ALL of:
    /// 1. `focusedWindow` (the focus ANCHOR, `focusedWindowID`, so a
    ///    frontmost tiled-sticky traveler is recognized, not the
    ///    stale local slot) resolves to a tracked window;
    /// 2. the OS frontmost app shares that window's pid;
    /// 3. the event loop still observes that pid;
    /// 4. no ignored panel is latched for that pid.
    ///
    /// Any nil/mismatch fails closed. A self-raise in flight is not
    /// a bypass: the command is allowed only once the OS frontmost
    /// pid actually matches, so an activation race rejects a
    /// shortcut rather than mutating a hidden window.
    func focusedCommandDenial(
        for command: String
    ) -> CommandResponse? {
        guard let frontmostPID = frontmostPIDProvider,
            FocusedCommandPolicy.isFocused(command)
        else { return nil }
        // Sampled ONCE, before the guard: the log below must
        // print the pid that actually denied, not a re-sample
        // that may have changed in exactly the racy activation
        // window this seam diagnoses.
        let front = frontmostPID()
        if foregroundOwned(front: front) { return nil }
        // The wake heal (#1130), one-shot and time-bounded: the
        // wake payment's activation can be refused, so re-seed
        // from the real frontmost (a blocking AX read, paid at
        // most once per arm) and re-ask before failing the press.
        if consumeWakeFocusHeal(), reseedFromFrontmostForHeal() {
            if foregroundOwned(front: front) {
                onLog(
                    "wake focus heal: reseeded from frontmost, "
                        + "allowed \(command)"
                )
                return nil
            }
        }
        // The hotkey path discards the response, so a denial
        // is otherwise invisible — the "#483 `_and_follow`
        // does nothing" trap. Log which clause denied: the
        // anchor/frontmost divergence is usually a dropped
        // cooperative activate (#463).
        logFocusedCommandDenial(
            command,
            focused: focusedWindow,
            front: front
        )
        return .fail("no managed window is currently focused")
    }

    /// The #292 ownership clauses in one place, so the wake heal
    /// (#1130) re-asks the same question after its reseed.
    private func foregroundOwned(front: pid_t?) -> Bool {
        guard let focused = focusedWindow,
            let front,
            front == focused.pid,
            eventLoop.observes(pid: focused.pid),
            !ignoredPanel.active.contains(focused.pid)
        else { return false }
        return true
    }

    /// One line naming the denied command, both sides of the
    /// divergence, and the clause that failed.
    private func logFocusedCommandDenial(
        _ command: String,
        focused: ManagedWindow?,
        front: pid_t?
    ) {
        let anchor = focused.map {
            "window \($0.id.raw) pid \($0.pid)"
        }
        let reason: String
        if let focused, let front {
            if front != focused.pid {
                reason = "frontmost pid \(front) is another app"
            } else if !eventLoop.observes(pid: focused.pid) {
                reason = "pid unobserved"
            } else {
                reason = "ignored panel latched"
            }
        } else if focused == nil {
            reason = "no focus anchor"
        } else {
            reason = "foreground unknown"
        }
        onLog(
            "preflight (#292): denied \(command) — anchor "
                + "\(anchor ?? "none"), \(reason)"
        )
    }
}
