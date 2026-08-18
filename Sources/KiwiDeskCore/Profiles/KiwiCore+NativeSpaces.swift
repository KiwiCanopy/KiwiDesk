import Foundation

/// Per-native-space profile binding: each Mission Control
/// desktop can carry its own profile, swapped in when the user
/// switches native Spaces.
extension KiwiCore {
    // MARK: - Commands

    /// `bind_profile_to_native_space(native_space, profile)`.
    /// The binding applies immediately when the bound space is
    /// the current one, and on every future switch to it.
    func bindProfileToNativeSpace(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let number = args.first?.intValue, number >= 1
        else {
            return .fail(
                "expected native space number (1-based)"
            )
        }
        guard
            let profile = args.dropFirst().first?.stringValue,
            !profile.isEmpty
        else {
            return .fail("expected profile name")
        }
        nativeSpaceBindings[number] = profile
        if !profiles.list().contains(profile) {
            onLog(
                "bind_profile_to_native_space: profile "
                    + "'\(profile)' does not exist (yet)"
            )
        }
        applyNativeSpaceBinding()
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
    func handleNativeSpaceChange() {
        let number = NativeSpaces.activeDesktopNumber()
        lastNativeSwitch = Date()
        let secondarySwitch =
            number == lastNativeSpace
            && state.workspaces.allDisplays.count > 1
            && DisplaySpacesSetting.hasSeparateSpaces()
        if let last = lastNativeSpace, last != number,
            let active = state.workspaces.activeSpace
        {
            rememberVirtualSpace(active, leaving: last)
        }
        lastNativeSpace = number
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
            applyNativeSpaceBinding()
            if let number,
                let target = virtualSpaceTarget(for: number)
            {
                state.workspaces.activate(target)
                // Never animate here: this desktop's windows
                // just (re)appeared, there is nothing to fly
                // around.
                retile(animated: false, force: true)
                emitSpaceChange()
            } else if !NativeSpaces.activeSpaceIsUser() {
                // Arrived on a fullscreen/system space (#670):
                // the nil number skipped the retile above and
                // the settle stands down, so sync the bars
                // directly — the per-display verdict retires
                // them instead of leaving the panels painted
                // over the fullscreen app for the 600 ms until
                // the settle's own sync.
                updateAppBar()
                updateSpaceBar()
            }
        }
        emitNativeSpaceChange()
        settleAfterNativeSwitch(number)
    }

    // MARK: - Per-Desktop Space memory (#888)

    /// The memory key for the current main display — see
    /// `DesktopMemory` for why the keying is per display and
    /// mode-independent.
    private var virtualSpaceMemoryKey: String {
        NativeSpaces.mainDisplayUUID() ?? "main"
    }

    /// Records the Space the main display's outgoing Desktop
    /// was showing.
    func rememberVirtualSpace(
        _ space: SpaceID,
        leaving desktop: Int
    ) {
        desktopMemory
            .virtualSpaces[virtualSpaceMemoryKey, default: [:]][
                desktop
            ] = space
    }

    /// The Space a native Desktop should show: the one it
    /// showed last, or the first space as default. A remembered
    /// SpaceID foreign to the CURRENT space set falls back too
    /// (#888): the binding apply just before this read may have
    /// swapped profiles, and a stale id would activate a Space
    /// the new profile does not have — missing and stale take
    /// the same exit.
    func virtualSpaceTarget(for native: Int) -> SpaceID? {
        let spaces = state.workspaces.allSpaces
        if let remembered =
            desktopMemory
            .virtualSpaces[virtualSpaceMemoryKey]?[native],
            spaces.contains(where: { $0.id == remembered })
        {
            return remembered
        }
        return spaces.first?.id
    }

    /// The post-switch AX reconcile re-tracks this desktop's
    /// windows over the next few hundred ms; afterwards,
    /// re-assert the layout (stashing included) and hand
    /// focus to the restored space — the OS may have focused
    /// a stashed window during the transition. Keyed (#49):
    /// rapid switches keep only the latest settle — a stale
    /// task either no-op'd on the `lastNativeSpace` guard or
    /// (switch away and back inside the delay) fired an early
    /// settle mid-reconcile — and `stop()` can now cancel it.
    private func settleAfterNativeSwitch(_ number: Int?) {
        deferred.schedule(
            .nativeSpaceSettle,
            after: .milliseconds(600)
        ) { [weak self] in
            self?.nativeSpaceSettle(ifStill: number)
        }
    }

    /// The settle body, split out so tests can fire it without
    /// waiting out the 600 ms schedule.
    func nativeSpaceSettle(ifStill number: Int?) {
        guard lastNativeSpace == number else { return }
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
    func applyNativeSpaceBinding() {
        guard let number = NativeSpaces.activeDesktopNumber(),
            let name = nativeSpaceBindings[number],
            name != profiles.currentName
        else { return }
        do {
            let profile = try profiles.load(name: name)
            apply(profile: profile, forceRetile: false)
            onLog(
                "native space \(number): loaded profile "
                    + "'\(name)'"
            )
        } catch {
            onLog(
                "native space \(number): cannot load "
                    + "profile '\(name)': \(error)"
            )
        }
    }
}
