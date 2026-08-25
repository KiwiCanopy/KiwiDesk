import Foundation

/// Per-native-space profile binding: each Mission Control
/// desktop can carry its own profile, swapped in when the user
/// switches native Spaces.
extension KiwiCore {
    // MARK: - Commands

    /// `bind_profile_to_desktop(desktop, profile)`.
    /// The binding applies immediately when the bound space is
    /// the current one, and on every future switch to it.
    func bindProfileToDesktop(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let number = args.first?.intValue, number >= 1
        else {
            return .fail(
                "expected Desktop number (1-based)"
            )
        }
        guard
            let profile = args.dropFirst().first?.stringValue,
            !profile.isEmpty
        else {
            return .fail("expected profile name")
        }
        desktopBindings[number] = profile
        if !profiles.list().contains(profile) {
            onLog(
                "bind_profile_to_desktop: profile "
                    + "'\(profile)' does not exist (yet)"
            )
        }
        // A verb, not a switch: no snapshot in hand, so this is
        // the one live read of the authority on this path.
        applyDesktopBinding(
            desktop: NativeSpaces.activeDesktopNumber()
        )
        return .ok()
    }

    // MARK: - Space switch reaction

    /// Native space switch: remember the Space the Desktop we
    /// left was showing, swap in the bound profile (if any),
    /// restore the new Desktop's Space, and notify subscribers.
    ///
    /// The Desktop that counts is the MAIN display's (#888,
    /// `NativeSpaces.activeDesktopNumber`). With "Displays have
    /// separate Spaces" on, a swipe on a secondary display fires
    /// this handler too — that arm reconciles and retiles the
    /// arrived windows but never selects a profile or moves the
    /// active Space. Shared mode and a single display never
    /// reach that arm, so their flow is exactly the pre-#888
    /// one.
    func handleDesktopChange() {
        let snapshot = NativeSpaces.desktopSnapshot()
        let number = snapshot.authority
        lastDesktopSwitch = Date()
        // A secondary display switched: the authority is a live
        // number that did not move, and some OTHER display's
        // current Space did. Both halves are read from the ONE
        // snapshot, so no mode read and no display count is
        // needed — shared mode carries one managed display, which
        // cannot produce an "other display" diff, and a single
        // display cannot either.
        //
        // `number != nil` is load-bearing: `nil == nil` is
        // satisfied by a main display sitting on a
        // fullscreen/system space AND by SkyLight being
        // unavailable, which is exactly the conflation #670 bans
        // deciding on (state-and-layout.md — the verdict is
        // `isUser`, never the nil number). Nil falls through to
        // the main arm, whose fullscreen branch stands down the
        // way it did before #888 (review, 2026-08-18).
        let changed = switchedDisplays(in: snapshot)
        let secondarySwitch = Self.isSecondarySwitch(
            authority: number,
            lastAuthority: lastDesktop,
            changed: changed,
            mainUUID: snapshot.mainUUID
        )
        // Every question below is answered from `snapshot` — the
        // memory key included, so the Space a Desktop is
        // remembered under and the Desktop that was
        // authoritative come from ONE reading (review round 2).
        let memoryKey = Self.virtualSpaceMemoryKey(
            mainUUID: snapshot.mainUUID
        )
        if let last = lastDesktop, last != number,
            let active = state.workspaces.activeSpace
        {
            rememberVirtualSpace(
                active,
                leaving: last,
                key: memoryKey
            )
        }
        lastDesktop = number
        if secondarySwitch {
            // A secondary display's Desktop switched: the
            // binding authority is unmoved, so the profile and
            // the active Space stand down. The windows that
            // arrived with the switch still need placing now —
            // the 600 ms settle would otherwise be the first
            // full pass — and the bars re-sync so a fullscreen
            // arrival retires that display's panels (#670's
            // per-display verdicts).
            retile(animated: false, force: true)
            updateAppBar()
            updateSpaceBar()
        } else {
            applyDesktopBinding(desktop: number)
            if let number,
                let target = virtualSpaceTarget(
                    for: number,
                    key: memoryKey
                )
            {
                state.workspaces.activate(target)
                // Never animate here: this desktop's windows
                // just (re)appeared, there is nothing to fly
                // around.
                retile(animated: false, force: true)
                emitSpaceChange()
            } else if !snapshot.currentSpaceIsUser(
                on: snapshot.mainUUID
            ) {
                // Arrived on a fullscreen/system space (#670):
                // the nil number skipped the retile above and
                // the settle stands down, so sync the bars
                // directly — the per-display verdict retires
                // them instead of leaving the panels painted
                // over the fullscreen app for the 600 ms until
                // the settle's own sync.
                //
                // The verdict is read for the MAIN display, the
                // one `number` is keyed to (review, 2026-08-18):
                // the global-focus read could answer for a
                // secondary display, so a fullscreen main display
                // with focus on a secondary user space skipped
                // both branches and left the bars painted over
                // the fullscreen app.
                updateAppBar()
                updateSpaceBar()
            }
        }
        emitDesktopChange(snapshot, changed: changed)
        settleAfterDesktopSwitch(number)
    }

    /// Whether this switch belongs to a secondary display: the
    /// authority is a live number that did not move, and some
    /// display OTHER than the main one changed its Space.
    ///
    /// A pure decision, so it is assertable without a
    /// WindowServer (`SecondarySwitchTests`) — the arm it gates
    /// force-retiles, and a retile is only observable on a host
    /// with a screen.
    ///
    /// **`authority != nil` is the load-bearing clause.** A nil
    /// authority is satisfied by a main display on a
    /// fullscreen/system space AND by SkyLight being unavailable,
    /// which is the conflation #670 bans deciding on
    /// (state-and-layout.md: the fullscreen verdict is `isUser`,
    /// never the nil Mission Control number). Without it, a
    /// fullscreen main display took this arm and force-retiled
    /// where the pre-#888 handler — and `desktopSettle` —
    /// deliberately stand down, and a host without SkyLight
    /// force-retiled on every switch (review, 2026-08-18).
    static func isSecondarySwitch(
        authority: Int?,
        lastAuthority: Int?,
        changed: [String],
        mainUUID: String?
    ) -> Bool {
        guard let authority, authority == lastAuthority else {
            return false
        }
        return changed.contains { $0 != mainUUID }
    }

    /// The display UUIDs whose current Space differs from the
    /// last reading, re-stamping the memory as it goes.
    ///
    /// Called ONCE per switch, and its answer threaded to the
    /// emit: the switch arm and the event must not name different
    /// displays, and a second call would diff against the stamp
    /// the first one just wrote (review, 2026-08-18).
    func switchedDisplays(
        in snapshot: DesktopSnapshot
    ) -> [String] {
        let previous = desktopMemory.lastDisplaySpaces
        desktopMemory.lastDisplaySpaces = snapshot.currentSpaces
        return
            snapshot.currentSpaces
            .filter { $0.value != previous[$0.key] }
            .keys.sorted()
    }

    /// The post-switch AX reconcile re-tracks this desktop's
    /// windows over the next few hundred ms; afterwards,
    /// re-assert the layout (stashing included) and hand
    /// focus to the restored space — the OS may have focused
    /// a stashed window during the transition. Keyed (#49):
    /// rapid switches keep only the latest settle — a stale
    /// task either no-op'd on the `lastDesktop` guard or
    /// (switch away and back inside the delay) fired an early
    /// settle mid-reconcile — and `stop()` can now cancel it.
    private func settleAfterDesktopSwitch(_ number: Int?) {
        deferred.schedule(
            .desktopSettle,
            after: .milliseconds(600)
        ) { [weak self] in
            self?.desktopSettle(ifStill: number)
        }
    }

    /// The settle body, split out so tests can fire it without
    /// waiting out the 600 ms schedule.
    func desktopSettle(ifStill number: Int?) {
        guard lastDesktop == number else { return }
        // A fullscreen/system space: the retile, z-order
        // restore and refocus stand down (#670) — the refocus
        // would AX-raise the desktop's focused window behind
        // the fullscreen app. The bars must still sync: the
        // panels join every Space by construction, the switch
        // handler skipped its retile on the nil number, so
        // this sync is what retires them (review 2026-08-03).
        guard NativeSpaces.activeSpaceIsUser() else {
            updateAppBar()
            updateSpaceBar()
            return
        }
        retile(animated: false, force: true)
        // The switch rebuilt this desktop's windows with
        // arbitrary stacking; put the overlapping
        // layouts' z-order back before handing focus over.
        scheduleZOrderRestore()
        if let focused = activeSpace?.focused,
            state.windows[focused]?.isFullscreen != true
        {
            // The instant retile above already placed the
            // windows; re-tiling on focus would fly them
            // from stale frames (issue #11). A fullscreen
            // window can still hold the focused slot (the
            // fold never clears it, #670 review) — raising
            // it would switch the user to its Space, so it
            // is the one focus this settle never re-asserts.
            focusWindow(
                focused,
                refocusRetile: false,
                warp: true
            )
        }
    }

    /// Loads the profile bound to the active Desktop — the MAIN
    /// display's current one (#888). No-ops without SkyLight
    /// (single-space fallback), when the Desktop has no binding,
    /// or when the bound profile is already active. All native
    /// Desktops without a binding share whatever profile is
    /// current.
    ///
    /// A caller holding a `DesktopSnapshot` passes its
    /// `authority` rather than letting this re-read the topology
    /// (review round 2, 2026-08-18); `desktop: nil` from such a
    /// caller means "no authoritative Desktop", which no-ops, so
    /// the live read belongs to the no-argument convenience
    /// alone.
    func applyDesktopBinding(desktop: Int?) {
        guard let number = desktop,
            let name = desktopBindings[number],
            name != profiles.currentName
        else { return }
        do {
            let profile = try profiles.load(name: name)
            apply(profile: profile, forceRetile: false)
            onLog(
                "Desktop \(number): loaded profile "
                    + "'\(name)'"
            )
        } catch {
            onLog(
                "Desktop \(number): cannot load "
                    + "profile '\(name)': \(error)"
            )
        }
    }
}
