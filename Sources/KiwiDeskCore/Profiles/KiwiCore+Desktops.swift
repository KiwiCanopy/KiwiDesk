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
        // A verb, not a switch: no snapshot in hand, so this is
        // the one reading of the topology on this path — stamped,
        // so the Desktop being bound carries an identity before
        // anything files under it (#1147).
        let snapshot = stampedDesktopSnapshot()
        // The DECLARATION stays a Mission Control number — the
        // only name for a Desktop a user has (#1149) — and the
        // binding is FILED under whichever Desktop that number
        // names right now. A number naming no Desktop yet files
        // as a number and pins when that Desktop appears, which
        // is the "takes effect when it next activates" this verb
        // always had.
        let desktop = snapshot.space(numbered: number)
        desktopBindings[
            desktop.flatMap { snapshot.key(of: $0.id) }
                ?? .number(number)
        ] = DesktopBinding(
            profile: profile,
            desktop: number
        )
        if !profiles.list().contains(profile) {
            onLog(
                "bind_profile_to_desktop: profile "
                    + "'\(profile)' does not exist (yet)"
            )
        }
        applyDesktopBinding(in: snapshot)
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
    /// arrived windows and moves THAT display onto the Space its
    /// arriving Desktop should show (#1230), while the profile
    /// still stands down. Shared mode and a single display never
    /// reach that arm, so their flow is exactly the pre-#888
    /// one.
    func handleDesktopChange() {
        // Stamped (#1147): a Desktop the user just created is
        // stamped at the first switch that shows it, and every
        // question below is still answered from this ONE reading.
        let snapshot = stampedDesktopSnapshot()
        let number = snapshot.authority
        // The arriving Desktop, answered from the SAME snapshot
        // (#1147): its stamp where it carries one, its Mission
        // Control number where it does not.
        let key = snapshot.mainCurrentKey
        lastDesktopSwitch = Date()
        // A secondary display switched: the authority is a live
        // Desktop that did not move, and some OTHER display's
        // current Space did. Both halves are read from the ONE
        // snapshot, so no mode read and no display count is
        // needed — shared mode carries one managed display, which
        // cannot produce an "other display" diff, and a single
        // display cannot either.
        //
        // `key != nil` is load-bearing: `nil == nil` is
        // satisfied by a main display sitting on a
        // fullscreen/system space AND by SkyLight being
        // unavailable, which is exactly the conflation #670 bans
        // deciding on (state-and-layout.md — the verdict is
        // `isUser`, never the nil Desktop). Nil falls through to
        // the main arm, whose fullscreen branch stands down the
        // way it did before #888 (review, 2026-08-18).
        let diff = switchedDisplays(in: snapshot)
        let changed = diff.changed
        let secondarySwitch = Self.isSecondarySwitch(
            authority: key,
            lastAuthority: lastDesktop,
            changed: changed,
            mainUUID: snapshot.mainUUID
        )
        // Every question below is answered from `snapshot`, so
        // the Space a Desktop is remembered under and the Desktop
        // that was authoritative come from ONE reading (review
        // round 2).
        //
        // The Desktop being LEFT is not resolved here at all: its
        // key was taken from the snapshot of the switch that
        // ARRIVED on it, and re-deriving it from a number in the
        // topology we have already left is the renumber #1147
        // closes.
        if let leaving = lastDesktop, leaving != key,
            let active = state.workspaces.activeSpace
        {
            rememberVirtualSpace(active, leaving: leaving)
        }
        lastDesktop = key
        if secondarySwitch {
            // A secondary display's Desktop switched: the
            // binding authority is unmoved, so the PROFILE stands
            // down. The Space that display shows does not —
            // #1230 ruling 3 moves it onto the one its arriving
            // Desktop should show, before the retile that draws
            // the result. The windows that arrived still need
            // placing now (the 600 ms settle would otherwise be
            // the first full pass), and the bars re-sync so a
            // fullscreen arrival retires that display's panels
            // (#670's per-display verdicts).
            let before = state.workspaces.activeSpace
            moveSwitchedDisplaySpaces(diff, in: snapshot)
            retile(animated: false, force: true)
            updateAppBar()
            updateSpaceBar()
            // Swiping the display that HOLDS the active Space
            // moves it, and a silent active-Space change is one
            // Lua and the CLI cannot see — the main arm emits for
            // the same reason.
            if state.workspaces.activeSpace != before {
                emitSpaceChange()
            }
        } else {
            applyDesktopBinding(in: snapshot)
            if let key,
                let target = virtualSpaceTarget(
                    for: key,
                    in: snapshot
                )
            {
                state.workspaces.activate(target)
                oweReturningFocus(
                    for: target,
                    native: snapshot.mainCurrentSpace
                )
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
        // #1145: carry the sticky windows onto the Desktop this
        // switch revealed — eagerly, so they are there when the
        // user is, and AFTER the arms above activated the
        // arriving Space, since a ∞ window renders on the active
        // space and the carry follows the render. Threaded from
        // the ONE snapshot (profiles.md); the settle is the net.
        refreshStickyReach(spaces: snapshot.spaces)
        emitDesktopChange(snapshot, changed: changed)
        settleAfterDesktopSwitch(key)
    }

    /// Whether this switch belongs to a secondary display: the
    /// authority is a live Desktop that did not move, and some
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
    /// never the nil Desktop). Without it, a
    /// fullscreen main display took this arm and force-retiled
    /// where the pre-#888 handler — and `desktopSettle` —
    /// deliberately stand down, and a host without SkyLight
    /// force-retiled on every switch (review, 2026-08-18).
    static func isSecondarySwitch(
        authority: DesktopKey?,
        lastAuthority: DesktopKey?,
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
    ) -> DisplaySwitch {
        let previous = desktopMemory.lastDisplaySpaces
        desktopMemory.lastDisplaySpaces = snapshot.currentSpaces
        return DisplaySwitch(
            changed: snapshot.currentSpaces
                .filter { $0.value != previous[$0.key] }
                .keys.sorted(),
            previous: previous
        )
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
    func applyDesktopBinding(in snapshot: DesktopSnapshot) {
        guard let binding = mainDesktopBinding(in: snapshot),
            binding.profile != profiles.currentName
        else { return }
        // The LOG names the number, which is the only name for a
        // Desktop the user has; the lookup above never does.
        do {
            let profile = try profiles.load(name: binding.profile)
            apply(profile: profile, forceRetile: false)
            onLog(
                "Desktop \(binding.desktop): loaded profile "
                    + "'\(binding.profile)'"
            )
        } catch {
            onLog(
                "Desktop \(binding.desktop): cannot load "
                    + "profile '\(binding.profile)': \(error)"
            )
        }
    }
}
