import Foundation

/// The Desktop↔Space relationship, and the ONE door onto it
/// (#1230). Every consumer asking "which Space does this Desktop
/// show", "which Spaces are taken" or "what is in this Space,
/// away members included" asks here; `ProfileSpacesSeamTests`
/// pins that, and pins the refused Desktop-keyed store
/// negatively.
///
/// **Per-Desktop Space CONTENTS are never stored, and this is the
/// canonical argument.** The discriminator is WHEN a record is
/// authoritative. A window's Desktop is read from the compositor
/// continuously (`DesktopMemory.readCensus` / `readWindowSpace`),
/// so a `[DesktopKey: SpaceSet]` copy would be read while the
/// thing it copies is still moving — and every disagreement is a
/// window that vanishes or appears twice. It would also owe its
/// own prune, re-key, #634 reset, dormancy rule and migration —
/// the enders `forgetAway` already owns for the same facts —
/// while retiring none of the records below.
///
/// "KiwiDesk's own fact versus the WindowServer's" is the WEAKER
/// form and does not hold: `AwayWindow.nativeSpace` is a stored
/// copy of a WindowServer fact, admitted because the #1146
/// census reconciles it continuously. `ProfilePartitioning`
/// (`KiwiCore+ProfileSpaces.swift`) is the other side — written
/// as a profile goes inactive, read as it returns, so store and
/// live truth are never both authoritative.
///
/// The partition is EMERGENT instead, and measured to work
/// (#1230's probe): `rememberedSpaces` and `departedSlots` are
/// keyed by `WindowID` and name no Desktop at all, and a window
/// lives on exactly one Desktop, so a per-window record
/// partitions by Desktop for free. `honoredFocus` is a per-Space
/// per-native-Desktop debt, and `virtualSpaces` a one-`SpaceID`
/// cursor. Four records, three subjects, no duplication.
///
/// **The obligation that falls out:** a new per-`Space` field is
/// keyed by `WindowID` or it is SHARED across Desktops — read
/// `Space`'s stored properties for which are which rather than
/// trusting a list here, which rots silently. #1230 measured the
/// one collision that exists today, `scrollRest`'s, as
/// unobservable: the #1207 refocus re-anchors the viewport before
/// it is drawn. Should a shared field ever bite, the fix is a
/// staleness rule at the one context build — never a
/// Desktop-keyed map, which is the refused store by the back
/// door.
///
/// **Every entry point takes the Desktop's KEY rather than
/// reading the topology.** A switch handler holds a
/// `DesktopSnapshot` and asks it for the key, so the Space a
/// Desktop is remembered under and the Desktop that was
/// authoritative come from one reading (review round 2,
/// 2026-08-18). Since #1147 that key is the Desktop's own stamp
/// where it carries one, so an entry survives a renumber — which
/// is what the memory was silently losing.
extension KiwiCore {
    /// Records the Space the Desktop being left was showing.
    func rememberVirtualSpace(
        _ space: SpaceID,
        leaving desktop: DesktopKey
    ) {
        desktopMemory.virtualSpaces[desktop] = space
        desktopMemory.spaceMemoryEstablished = true
    }

    /// The Space a Desktop should show: the one it showed last,
    /// or — on a Desktop with no memory — one no OTHER Desktop is
    /// showing (#1230), so a fresh Desktop stops landing on a
    /// Space whose windows are all somewhere else.
    ///
    /// A remembered SpaceID foreign to the CURRENT space set
    /// falls back too (#888): the binding apply just before this
    /// read may have swapped profiles, and a stale id would
    /// activate a Space the new profile does not have — missing
    /// and stale take the same exit.
    ///
    /// **TOTAL wherever it was total before.** The switch arm
    /// reads `if let key, let target = virtualSpaceTarget(...)`,
    /// and `oweReturningFocus` is reached for every user-Desktop
    /// arrival only because this answers for an unremembered one
    /// (`DesktopFocusMemoryTests`). A nil here would silently skip
    /// the activate, the focus debt, the retile and the emit — so
    /// an exhausted pick returns the first Space, never nothing.
    func virtualSpaceTarget(
        for desktop: DesktopKey,
        in snapshot: DesktopSnapshot
    ) -> SpaceID? {
        // Narrowed to the MAIN display's Spaces for the same
        // reason the secondary arm narrows to its own: activating
        // a Space that lays out on the other screen parks this
        // display on what it already showed and moves the active
        // Space to the wrong screen, taking the focus debt and
        // the retile with it. Falls back to every Space so the
        // answer stays TOTAL where no display is known.
        let main = display(forUUID: snapshot.mainUUID)
        let onMain = main.map { state.workspaces.spaces(on: $0) }
        let candidates =
            (onMain?.isEmpty == false)
            ? onMain! : state.workspaces.allSpaces.map(\.id)
        return virtualSpaceTarget(
            for: desktop,
            among: candidates,
            in: snapshot
        )
    }

    /// The same decision over a narrowed candidate list — a
    /// secondary display picks among the Spaces that lay out on
    /// IT (#1230, ruling 3), or the swipe would show that screen
    /// a Space belonging to the other one. One copy of the rule,
    /// two candidate sets.
    func virtualSpaceTarget(
        for desktop: DesktopKey,
        among candidates: [SpaceID],
        in snapshot: DesktopSnapshot
    ) -> SpaceID? {
        if let remembered = desktopMemory.virtualSpaces[desktop],
            candidates.contains(remembered)
        {
            return remembered
        }
        let taken = spacesShownElsewhere(
            excluding: desktop,
            in: snapshot
        )
        let declared = currentDeclaredSpaces()
        let free = candidates.first {
            !taken.contains($0)
                && (declared?.contains($0) ?? true)
        }
        return free ?? candidates.first
    }

    /// The Spaces a Desktop other than `desktop` is showing.
    ///
    /// Only Desktops the snapshot still lists count. A record
    /// whose Desktop no reading names stays DORMANT rather than
    /// pruned (#1147 — an unplugged screen's Desktops come back
    /// with their stamps), and counting one would retire a Space
    /// nothing is using.
    ///
    /// The live half is `visibleSpaces` — the active Space plus
    /// every display's shown one — because a Space on a secondary
    /// screen is in use whoever is looking at it. The departing
    /// Desktop's own Space is already in the memory by the time
    /// the switch asks: `handleDesktopChange` remembers before it
    /// resolves.
    func spacesShownElsewhere(
        excluding desktop: DesktopKey,
        in snapshot: DesktopSnapshot
    ) -> Set<SpaceID> {
        let present = snapshot.presentKeys
        var taken = state.workspaces.visibleSpaces
        for (key, space) in desktopMemory.virtualSpaces
        where key != desktop && present.contains(key) {
            taken.insert(space)
        }
        return taken
    }

    /// The active profile's declared Spaces, or nil when there is
    /// no profile to ask — in which case every live Space is a
    /// candidate, which is what this answered before #1230.
    ///
    /// Read from disk on the FALLBACK path only: a Desktop with a
    /// memory returns above, so this costs one small JSON read per
    /// Desktop per session.
    ///
    /// Asking the profile rather than the live set is belt AND
    /// braces. #1230's own prune-on-switch means the live set
    /// should already be this profile's alone — but a Space
    /// created live (`create_space`) is in the live set and in no
    /// profile, and landing a fresh Desktop on one of those is
    /// the confusion this pick exists to remove.
    func currentDeclaredSpaces() -> Set<SpaceID>? {
        guard let name = profiles.currentName else { return nil }
        do {
            return try profiles.read(name: name).declaredSpaces
        } catch {
            // Falling back keeps this TOTAL, which the switch arm
            // needs — but a broken profile would otherwise drop a
            // ruled behaviour with no trace, so it says so.
            onLog(
                "first-visit pick: cannot read profile "
                    + "'\(name)' (\(error)); every live Space is "
                    + "a candidate"
            )
            return nil
        }
    }

    /// Moves a display that switched Desktop onto the Space that
    /// Desktop should show (#1230, ruling 3).
    ///
    /// Measured 2026-09-04 on two screens: before this, a swipe on
    /// a secondary display emitted `desktop_change` for that
    /// monitor and moved no Space at all, so the screen kept
    /// showing the Space its PREVIOUS Desktop had — the confusion
    /// this issue removes, one screen over.
    ///
    /// The profile deliberately stands down: it stays the main
    /// screen's (#888). Only the Space this screen shows moves.
    ///
    /// The departing Desktop is resolved from the reading
    /// `switchedDisplays` already took, never a second one — that
    /// function stamps the memory as it diffs, so asking again
    /// would compare against what the first call just wrote.
    func moveSwitchedDisplaySpaces(
        _ diff: DisplaySwitch,
        in snapshot: DesktopSnapshot
    ) {
        for uuid in diff.changed where uuid != snapshot.mainUUID {
            guard let display = display(forUUID: uuid) else {
                continue
            }
            if let left = diff.previous[uuid],
                let leaving = snapshot.key(of: left),
                let shown = state.workspaces.activeSpace(
                    on: display
                )
            {
                rememberVirtualSpace(shown, leaving: leaving)
            }
            guard let arriving = snapshot.currentKey(on: uuid),
                let target = virtualSpaceTarget(
                    for: arriving,
                    among: state.workspaces.spaces(on: display),
                    in: snapshot
                )
            else { continue }
            state.workspaces.show(target, on: display)
        }
    }

    /// Re-keys the session's Desktop-keyed state onto this
    /// topology's keys, on the same reading the bindings re-key
    /// on (#1147's `keyMoves`, which that lane made generic FOR
    /// this one).
    ///
    /// **Every holder, not just the map.** `lastDesktop` carries
    /// the same key and is compared across snapshots by
    /// `isSecondarySwitch`, so leaving it behind reproduces the
    /// defect one holder over: the next switch compares
    /// `.identity(x)` against `.number(n)` for ONE Desktop,
    /// reads a secondary swipe as a main one, files a phantom
    /// departure and lands the main display on the wrong Space
    /// (code review, 2026-09-04). A new Desktop-keyed field owes
    /// itself a line here.
    ///
    /// Without it the memory is written under one key and read
    /// under another. `stampedDesktopSnapshot` returns the
    /// CONFIRMED reading, so a Desktop stamped this session keys
    /// by its NUMBER for exactly one call — the call that files
    /// its departure — and by its identity forever after. Every
    /// later return then missed, and `spacesShownElsewhere` read
    /// that Desktop's own orphaned entry as another Desktop's,
    /// so the pick actively AVOIDED the Space it was left on:
    /// #1230's own defect, on every freshly created Desktop.
    func reconcileDesktopSpaceMemory(in snapshot: DesktopSnapshot) {
        // The two holders are INDEPENDENT: an empty map is the
        // ordinary state on the switch that first stamps a
        // Desktop, and gating the cursor's re-key on the map's
        // early return is how it was missed the first time.
        rekeyLastDesktop(in: snapshot)
        let result = Self.keyMoves(
            in: desktopMemory.virtualSpaces,
            snapshot: snapshot
        )
        guard !result.moves.isEmpty || !result.drops.isEmpty
        else { return }
        var out = desktopMemory.virtualSpaces
        for key in result.drops { out[key] = nil }
        for (from, to) in result.moves {
            out[to] = out[from]
            out[from] = nil
        }
        desktopMemory.virtualSpaces = out
    }

    /// The other holder of a `DesktopKey` across snapshots.
    /// Resolved through the topology rather than compared as a
    /// value: two keys can name ONE Desktop while it is being
    /// stamped, and `isSecondarySwitch` decides on that
    /// comparison.
    private func rekeyLastDesktop(in snapshot: DesktopSnapshot) {
        guard let last = lastDesktop,
            let space = snapshot.space(for: last),
            let now = snapshot.key(of: space.id), now != last
        else { return }
        lastDesktop = now
    }

    /// Forgets which Space each Desktop was showing (#634).
    ///
    /// A CLEARED memory rather than an absent one: the map became
    /// durable in #1230, so the discard must reach the file, and
    /// only an established memory is stamped into a write.
    func forgetDesktopSpaceMemory() {
        desktopMemory.virtualSpaces = [:]
        desktopMemory.spaceMemoryEstablished = true
    }

    /// Writes the Desktop→Space memory to `gui.json` (#1230).
    ///
    /// Nothing else does at a moment that matters: the eight
    /// sidecar writers are all user actions, so without this the
    /// memory reached disk only if the user happened to save
    /// something after their last swipe. Called at QUIT, where
    /// the session file is already written, and at the discard,
    /// which must not be re-adopted at the next boot.
    ///
    /// **Only where KiwiDesk owns the config.** A Lua-owned setup
    /// has no sidecar to write, so the memory stays session-only
    /// there — a limitation of config ownership rather than a
    /// gap, and `docs/spaces-and-desktops.md` says so.
    func persistDesktopSpaceMemory() {
        guard isGuiManaged, desktopMemory.spaceMemoryEstablished,
            var live = guiConfigStore.load()
        else { return }
        // The STORE, never `saveGuiConfig` — that reloads the
        // whole config, which at quit would rebuild the Lua VM
        // the stop is tearing down. The write-time stamp fills
        // `desktopSpaces` in, so this hands the file back
        // unchanged otherwise.
        live.desktopSpaces = persistedDesktopSpaces() ?? [:]
        try? guiConfigStore.save(live)
    }
}
