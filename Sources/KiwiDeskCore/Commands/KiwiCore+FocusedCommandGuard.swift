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
    /// commands `FocusedCommandPolicy` classifies as focused, and
    /// of those only a call that names no window (#1518).
    ///
    /// Foreground ownership requires ALL of:
    /// 1. `focusedWindow` (the focus ANCHOR, `focusedWindowID`, so a
    ///    frontmost tiled-sticky traveler is recognized, not the
    ///    stale local slot) resolves to a tracked window;
    /// 2. the OS frontmost app shares that window's pid;
    /// 3. the event loop still observes that pid;
    /// 4. no ignored panel is latched for that pid.
    ///
    /// Any nil/mismatch fails closed. KiwiDesk's own raise in
    /// flight lets the verbs `FocusedCommandPolicy.raiseFlightExempt`
    /// names through (`ownRaiseInFlight`, #1812); every other verb
    /// waits until the OS frontmost pid actually matches.
    func focusedCommandDenial(
        for command: String,
        _ args: [JSONValue]
    ) -> CommandResponse? {
        guard let frontmostPID = frontmostPIDProvider,
            impliesFocus(command, args)
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
        if ownRaiseInFlight(command, front: front) {
            onLog(
                "preflight (#292): allowed \(command) — own raise "
                    + "toward the anchor in flight (#1812)"
            )
            return nil
        }
        // The hotkey path discards the response, so a denial
        // is otherwise invisible — the "#483 `_and_follow`
        // does nothing" trap. Log which clause denied: the
        // anchor/frontmost divergence is usually a dropped
        // cooperative activate (#463).
        let denial = denialSentences(
            focused: focusedWindow,
            front: front
        )
        onLog(
            "preflight (#292): denied \(command) — anchor "
                + "\(denial.anchor), \(denial.reason)"
        )
        return .fail(denial.error)
    }

    /// The #292 ownership clauses in one place, so the wake heal
    /// (#1130) re-asks the same question after its reseed.
    private func foregroundOwned(front: pid_t?) -> Bool {
        guard let focused = focusedWindow, let front else {
            return false
        }
        return owns(front: front, pid: focused.pid)
            && anchorManaged(focused)
    }

    /// The clauses that do not read the frontmost app: the loop
    /// observes the anchor's app and no ignored panel is latched.
    private func anchorManaged(_ focused: ManagedWindow) -> Bool {
        eventLoop.observes(pid: focused.pid)
            && !ignoredPanel.active.contains(focused.pid)
    }

    /// Whether `command` may run with only the frontmost clause
    /// failing (#1812): the verb is exempt, the anchor is the
    /// target of our raise in flight, and the app in front is
    /// still the managed app that raise LEFT — so a switch the
    /// user made since is #292's refusal, never ours to override.
    private func ownRaiseInFlight(
        _ command: String,
        front: pid_t?
    ) -> Bool {
        guard FocusedCommandPolicy.raiseFlightExempt.contains(command),
            let focused = focusedWindow,
            let front,
            let flight = raiseFlight,
            anchorManaged(focused),
            flight.inFlight(
                toward: focused.id,
                pending: pendingFocusRaise,
                now: wallClock(),
                // Our raise is in flight as long as its echo is
                // believed ours (#887).
                bound: Self.selfRaiseEchoWindow
            ),
            owns(front: front, pid: flight.leftPID),
            !ignoredPanel.active.contains(front)
        else { return false }
        return Set(state.windows.all.map(\.pid)).contains {
            owns(front: flight.leftPID, pid: $0)
        }
    }

    /// Records the focus command's raise toward `id` and the app
    /// in front as it was issued — the app the raise leaves.
    func noteRaiseFlight(to id: WindowID) {
        guard let front = frontmostPIDProvider?() else {
            raiseFlight = nil
            return
        }
        raiseFlight = RaiseFlight(
            target: id,
            leftPID: front,
            raisedAt: wallClock()
        )
    }

    /// Whether the frontmost process is `pid`'s app — the
    /// loop's one reading of an announced pid (#1785).
    func owns(front: pid_t, pid: pid_t) -> Bool {
        eventLoop.names(front, appOf: pid)
    }

    /// Whether the one frontmost reading is `pid`'s app.
    func frontmostOwns(pid: pid_t) -> Bool {
        frontmostPIDProvider?().map { owns(front: $0, pid: pid) }
            ?? false
    }

    /// The denied clause, said twice from ONE reading — the
    /// log's `reason` and the response's `error`. An anchor
    /// missing because the ACTIVE Space is empty is the one
    /// clause whose error leaves the generic sentence (#1336);
    /// every other clause keeps it.
    private func denialSentences(
        focused: ManagedWindow?,
        front: pid_t?
    ) -> (anchor: String, reason: String, error: String) {
        let generic = "no managed window is currently focused"
        let anchor =
            focused.map { "window \($0.id.raw) pid \($0.pid)" }
            ?? "none"
        let reason: String
        if let focused, let front {
            if !owns(front: front, pid: focused.pid) {
                reason = "frontmost pid \(front) is another app"
            } else if !eventLoop.observes(pid: focused.pid) {
                reason = "pid unobserved"
            } else {
                reason = "ignored panel latched"
            }
        } else if focused == nil {
            if let empty = emptyActiveSpaceRefusal() {
                return (anchor, "no focus anchor — \(empty)", empty)
            }
            reason = "no focus anchor"
        } else {
            reason = "foreground unknown"
        }
        return (anchor, reason, generic)
    }

    /// The refusal for a focus anchor missing because the active
    /// Space holds nothing (#1336), or nil when it is not empty —
    /// members none of which is focused stay the generic case.
    /// Names the window a sibling Space on the SAME screen marks
    /// focused and the `focus_space` that brings it under the
    /// verb: `lastFocused`'s Space where it is among them, else
    /// the first in Space order. Same screen is the assigned
    /// display compared raw (the `FocusDistrust` reading), so an
    /// unassigned Space pairs only with unassigned ones and a
    /// Space on another screen is never named.
    func emptyActiveSpaceRefusal() -> String? {
        guard let active = activeSpace,
            state.effectiveMembers(of: active).isEmpty
        else { return nil }
        let sentence = "the active Space \(active.id.raw) is empty"
        let display = state.workspaces.display(of: active.id)
        typealias Marked = (window: ManagedWindow, space: SpaceID)
        let marked = state.workspaces.allSpaces
            .filter {
                $0.id != active.id
                    && state.workspaces.display(of: $0.id) == display
            }
            .compactMap { space -> Marked? in
                guard let focused = space.focused,
                    let window = state.windows[focused]
                else { return nil }
                return (window, space.id)
            }
        let last = state.workspaces.lastFocused
        guard
            let hit = marked.first(where: { $0.window.id == last })
                ?? marked.first
        else { return sentence }
        return sentence
            + "; the focused window (\(hit.window.appName)) is in "
            + "Space \(hit.space.raw) — focus_space \(hit.space.raw) "
            + "first"
    }
}
