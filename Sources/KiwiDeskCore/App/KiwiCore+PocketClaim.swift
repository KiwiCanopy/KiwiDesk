import Foundation

/// A `pocket_app` press's claim on its app's next window (#2612
/// ▸ 7), read through the one arrival door (#2629): only a window
/// WindowServer reported created, or any arrival where that route
/// is absent, is pocketed. The claim skips the App Rule in the fold,
/// so the #2478 follow never claims it, and a create still due
/// waits through `settleArrival`. The rows that tie a window to its
/// app are the installed bindings of `PocketAppLuaArg`'s shape.
extension KiwiCore {
    /// The arrival the live claim takes now, from the provenance
    /// `handle` read ahead of the fold; mirrored into the fold as
    /// `StateCoordinator.pocketClaimed`. One whose create is still
    /// due becomes the claim's candidate, filed by its rules but
    /// followed nowhere meanwhile, so an adoption keeps its App
    /// Rule — and a new window whose create trails it comes out of
    /// its rule's Space only as the create lands.
    func claimPocketArrival(
        _ event: KiwiEvent,
        provenance: ArrivalProvenance?
    ) -> PocketArrivalClaim? {
        guard case .windowCreated(let window) = event,
            let provenance,
            let bundle = window.appBundleID?.lowercased(),
            var claim = arrivals.livePocketClaim(
                for: bundle,
                at: wallClock()
            ),
            !claim.spent, !window.isTransientOverlay, !window.isFullscreen,
            state.pocketPhase(of: window.id) == nil
        else { return nil }
        switch provenance {
        case .created, .unreported:
            // A created window outranks a candidate still waiting,
            // which stays where the fold filed it.
            return .claimed(window.id)
        case .awaitingCreate:
            guard claim.candidate == nil else { return nil }
            claim.candidate = window.id
            arrivals.pocketClaims[bundle] = claim
            return .awaited(window.id)
        case .existing, .own:
            return nil
        }
    }

    /// Spends the claim on `id`: marked out, tied to its app where
    /// the row still exists, else in the general list while the
    /// capacity takes it, else left an ordinary window.
    /// `retiling` is false on the arrival path, whose event retile
    /// places it.
    func takePocketClaim(_ id: WindowID, retiling: Bool = true) {
        guard
            let bundle = state.windows[id]?.appBundleID?.lowercased(),
            let claim = arrivals.pocketClaims[bundle], !claim.spent
        else { return }
        arrivals.pocketClaims[bundle]?.spent = true
        // Its activation's launch debt is no open to follow (#1599).
        launchFollow.forget(pending: claim.bundleID)
        let keyed = claim.keyed && pocketAppRows().contains(claim.bundleID)
        guard keyed || state.pocketAcceptsMark(appWide.pocketCapacity)
        else { return }
        onLog("pocket: w\(id.raw) claimed for \(claim.bundleID)")
        markAsPocketWindow(
            id,
            owner: keyed ? claim.bundleID : nil,
            retiling: retiling
        )
    }

    /// The claim's arm of `settleArrival`, ahead of the event: a
    /// candidate created in the bound is claimed and beats the
    /// follow; one that goes or never gets a create frees the claim
    /// for the app's real window.
    func settlePocketClaim(
        _ id: WindowID,
        created: Bool,
        departing: Bool
    ) {
        guard let claim = arrivals.pocketClaim(awaiting: id) else {
            return
        }
        guard created, !departing else {
            arrivals.pocketClaims[claim.bundleID]?.candidate = nil
            return
        }
        takePocketClaim(id)
        launchFollow.dropSpawn(of: id)
    }

    /// `bundleID`'s Pocket key row among the installed bindings of
    /// every layer (#2612 ▸ 6) — the one answer to "the app's row
    /// exists", which the GUI reads for its chord too. An install
    /// keeps only rows whose chord registers, so a row left without
    /// a key ties nothing.
    public func pocketAppRow(for bundleID: String) -> KeyBinding? {
        installedLayers.flatMap(\.bindings).first {
            PocketAppLuaArg.bundleID(of: $0.lua) == bundleID.lowercased()
        }
    }

    /// The bundle ids whose Pocket key row is installed.
    func pocketAppRows() -> Set<String> {
        Set(
            installedLayers.flatMap(\.bindings).compactMap {
                PocketAppLuaArg.bundleID(of: $0.lua)
            }
        )
    }

    /// The installed rows, and those the stored base resolves to
    /// under any saved profile. It reads files, so it runs only off
    /// the switch path (#1245).
    private func pocketAppRowsInAnyProfile() -> Set<String> {
        var rows = pocketAppRows()
        guard isGuiManaged, let base = loadStructuredConfig()?.layers
        else { return rows }
        for profile in [nil] + profiles.allProfiles().map(Optional.some) {
            let layers = ConfigResolver.resolvedLayers(
                base: base,
                profile: profile?.layers
            )
            rows.formUnion(
                layers.flatMap(\.bindings).compactMap {
                    PocketAppLuaArg.bundleID(of: $0.lua)
                }
            )
        }
        return rows
    }

    private var installedLayers: [KeyLayer] {
        switch installedKeybindings {
        case .structured(let installed, _, _): installed
        case .lua(let installed, _): installed
        case nil: []
        }
    }

    /// Unties every window whose app's row is gone from every
    /// arrangement (#2612 ▸ 2, 12): it becomes an ordinary window on
    /// the active Space, tiling or floating as its rules say, never
    /// parked off-screen. Run after an install that is no profile
    /// apply — a row a switch leaves out keeps its tie — and after a
    /// restart's restore brings the slots back.
    func reconcilePocketKeys() {
        guard installedKeybindings != nil else { return }
        let rows = pocketAppRowsInAnyProfile()
        for slot in state.pocket {
            guard let app = slot.keyedApp, !rows.contains(app)
            else { continue }
            onLog(
                "pocket: \(app)'s key is gone — "
                    + "w\(slot.window.raw) untied"
            )
            guard state.windows[slot.window] != nil else {
                state.emptyPocket(slot.window)
                continue
            }
            unmarkPocketWindow(slot.window)
        }
    }
}
