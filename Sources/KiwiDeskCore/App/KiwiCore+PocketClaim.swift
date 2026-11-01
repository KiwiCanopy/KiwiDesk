import Foundation

/// A `pocket_app` press's claim on its app's next window (#2612
/// ▸ 7), read through the one arrival door (#2629): only a window
/// WindowServer reported created, or any arrival where that route
/// is absent, is pocketed. The claim skips the App Rule in the fold,
/// so the #2478 follow never claims it, and a create still due
/// waits through `settleArrival`. The rows that tie a window to its
/// app are the installed bindings of `PocketAppLuaArg`'s shape.
extension KiwiCore {
    /// The arrival the live claim takes, from the provenance
    /// `handle` read ahead of the fold; mirrored into the fold as
    /// `StateCoordinator.pocketClaimed`.
    func claimPocketArrival(
        _ event: KiwiEvent,
        provenance: ArrivalProvenance?
    ) -> WindowID? {
        guard case .windowCreated(let window) = event,
            let provenance,
            let bundle = window.appBundleID?.lowercased(),
            var claim = arrivals.livePocketClaim(at: wallClock()),
            claim.bundleID == bundle, claim.candidate == nil,
            !window.isTransientOverlay,
            state.pocketPhase(of: window.id) == nil
        else { return nil }
        switch provenance {
        case .created, .unreported:
            return window.id
        case .awaitingCreate:
            claim.candidate = window.id
            arrivals.pocketClaim = claim
            return window.id
        case .existing, .own:
            return nil
        }
    }

    /// Spends the claim on `id`: marked out, tied to its app where
    /// the row still exists, else in the general list while the
    /// capacity takes it, else left an ordinary window.
    func takePocketClaim(_ id: WindowID) {
        guard let claim = arrivals.pocketClaim else { return }
        arrivals.pocketClaim = nil
        guard state.windows[id] != nil else { return }
        let keyed = claim.keyed && pocketAppRows().contains(claim.bundleID)
        guard keyed || state.pocketAcceptsMark(appWide.pocketCapacity)
        else { return }
        onLog("pocket: w\(id.raw) claimed for \(claim.bundleID)")
        markAsPocketWindow(id, owner: keyed ? claim.bundleID : nil)
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
        guard arrivals.pocketClaim?.candidate == id else { return }
        guard created, !departing else {
            arrivals.pocketClaim?.candidate = nil
            return
        }
        takePocketClaim(id)
        launchFollow.dropSpawn(of: id)
    }

    /// The bundle ids whose Pocket key row the installed bindings
    /// carry (#2612 ▸ 6): a row whose chord installs, so one left
    /// without a key ties nothing.
    func pocketAppRows() -> Set<String> {
        let layers: [KeyLayer]
        switch installedKeybindings {
        case .structured(let installed, _, _): layers = installed
        case .lua(let installed, _): layers = installed
        case nil: return []
        }
        return Set(
            layers.flatMap(\.bindings).compactMap {
                PocketAppLuaArg.bundleID(of: $0.lua)
            }
        )
    }

    /// Unties every window whose app's row is gone (#2612 ▸ 2): it
    /// becomes an ordinary window on the active Space, tiling or
    /// floating as its rules say, never parked off-screen. Run after
    /// each install of the bindings.
    func reconcilePocketKeys() {
        guard installedKeybindings != nil else { return }
        let rows = pocketAppRows()
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
