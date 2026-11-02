import Foundation

/// The interactive-resize ratio seam (#458, #764): the value lands
/// in the session layer — never the global, never the authored
/// override, which keeps the number the profile or `init.lua`
/// wrote so `reset_layout_sizing` can return to it. Both the
/// keyboard `resize` verb and the mouse-drag drop
/// (`applyResizeAdjustment`) route here. The layer is per macOS
/// Desktop and per arrangement live on it (#2921):
/// `DesktopMemory.sessionRatios`, read through `sessionRatios(of:)`
/// alone, which every resolver overlay takes as a required argument
/// (`SessionRatioSeamTests`).
extension KiwiCore {
    /// The arrangement `space`'s sizes are filed under — the one
    /// rule every read, write and drop takes: a held Space's
    /// origin, else the arrangement an apply in flight installs,
    /// else the live one.
    func sizingOwner(of space: SpaceID) -> HeldOrigin.Arrangement? {
        if let held = state.heldSpaces[space] { return held.arrangement }
        return desktopMemory.installing?.arrangement ?? liveArrangement
    }

    /// The store key for `space` now: the Desktop its screen
    /// shows — else the one shared entry (no SkyLight, a screen no
    /// switch has filed yet, ruling 3) — and its `sizingOwner`.
    private func sizingKey(of space: SpaceID) -> SessionSizingKey {
        let owner = sizingOwner(of: space)
        guard case .shown(let desktop) = shownDesktop(of: space) else {
            return SessionSizingKey(desktop: nil, arrangement: owner)
        }
        return SessionSizingKey(desktop: desktop, arrangement: owner)
    }

    /// The sizes a resize wrote for `space` on the Desktop shown
    /// now under the arrangement live — the ONE read door. A
    /// Desktop not sized under it answers empty, so the overlay
    /// falls through to the override, then the global value.
    func sessionRatios(of space: SpaceID) -> SessionRatios {
        let key = sizingKey(of: space)
        return desktopMemory.sessionRatios[key.desktop]?[key.arrangement]?[
            space
        ] ?? SessionRatios()
    }

    /// Mutates `space`'s sizes on the Desktop shown now under the
    /// arrangement live; an entry left empty is dropped.
    func withSessionRatios(
        of space: SpaceID,
        _ body: (inout SessionRatios) -> Void
    ) {
        guard state.workspaces[space] != nil else { return }
        let key = sizingKey(of: space)
        var ratios = sizes(at: key)[space] ?? SessionRatios()
        body(&ratios)
        setSizes(at: key) {
            $0[space] = ratios == SessionRatios() ? nil : ratios
        }
    }

    private func sizes(at key: SessionSizingKey) -> DesktopMemory.SpaceRatios {
        desktopMemory.sessionRatios[key.desktop]?[key.arrangement] ?? [:]
    }

    private func setSizes(
        at key: SessionSizingKey,
        _ body: (inout DesktopMemory.SpaceRatios) -> Void
    ) {
        var byArrangement = desktopMemory.sessionRatios[key.desktop] ?? [:]
        var sizes = byArrangement[key.arrangement] ?? [:]
        body(&sizes)
        byArrangement[key.arrangement] = sizes.isEmpty ? nil : sizes
        desktopMemory.sessionRatios[key.desktop] =
            byArrangement.isEmpty ? nil : byArrangement
    }

    func writeSplitRatioH(_ value: Double, for space: SpaceID) {
        withSessionRatios(of: space) { $0.splitRatioH = value }
    }

    func writeSplitRatioV(_ value: Double, for space: SpaceID) {
        withSessionRatios(of: space) { $0.splitRatioV = value }
    }

    func writeMasterRatio(_ value: Double, for space: SpaceID) {
        withSessionRatios(of: space) { $0.masterRatio = value }
    }

    func writeSlotSize(_ value: ScrollSize, for space: SpaceID) {
        withSessionRatios(of: space) { $0.slotSize = value }
    }

    /// One grid axis's whole weight list (#763): "x" the columns,
    /// "y" the rows.
    func writeGridWeights(
        _ weights: [Double],
        axis: String,
        for space: SpaceID
    ) {
        withSessionRatios(of: space) {
            if axis == "x" {
                $0.gridColumnWeights = weights
            } else {
                $0.gridRowWeights = weights
            }
        }
    }

    // MARK: - Clearing doors (#2921 rulings 4 and 6)

    /// Clears one session field on every Space, Desktop and
    /// arrangement — the explicit global setters (`bsp.set_ratio_h`,
    /// `stack.set_master_ratio`, `scroll.set_slot_size`), a config
    /// load and a Settings apply call this so an explicit config
    /// write visibly applies everywhere instead of being shadowed
    /// by earlier interactive resizes (the #383 "visibly did
    /// nothing" trap, session-layer edition).
    func clearSessionRatios(
        _ clear: (inout SessionRatios) -> Void
    ) {
        mapSessionRatios { _, _, ratios in clear(&ratios) }
    }

    /// The per-space `_override` setters' sibling: the layer
    /// outranks the override, so an explicit write on one Space
    /// drops that Space's shadow on every Desktop and arrangement
    /// (#764).
    func clearSessionRatios(
        for space: SpaceID,
        _ clear: (inout SessionRatios) -> Void
    ) {
        mapSessionRatios { _, id, ratios in
            if id == space { clear(&ratios) }
        }
    }

    /// A load starts the Desktops shown now fresh — each live
    /// screen's, read through the one resolver, and the shared entry
    /// — every arrangement's sizes on them; other Desktops keep
    /// theirs.
    func forgetSessionRatiosOnShownDesktops() {
        desktopMemory.sessionRatios[nil] = nil
        for display in state.workspaces.allDisplays {
            let uuid = NativeSpaces.displayUUID(for: display.id) ?? ""
            if let desktop = shownDesktop(onScreen: uuid) {
                desktopMemory.sessionRatios[desktop] = nil
            }
        }
    }

    /// A save of a profile clears that arrangement's sizes on every
    /// Desktop — by the key, never by which Desktops show it now.
    func forgetSessionRatios(under arrangement: HeldOrigin.Arrangement) {
        mapSessionRatios { live, _, ratios in
            if live == arrangement { ratios = SessionRatios() }
        }
    }

    /// `reset_layout_sizing <space>`: that Space on the Desktop
    /// shown under the arrangement live; a Space with no screen
    /// (held, not yet placed) on every Desktop (ruling 7).
    func resetSessionRatios(of space: SpaceID) {
        guard state.workspaces.display(of: space) != nil else {
            forgetSessionRatios(of: space)
            return
        }
        withSessionRatios(of: space) { $0 = SessionRatios() }
    }

    /// Forgets `space` on every Desktop and arrangement — the
    /// explicit doors (an override setter, a mode change, a
    /// screenless reset).
    func forgetSessionRatios(of space: SpaceID) {
        clearSessionRatios(for: space) { $0 = SessionRatios() }
    }

    /// A dropped Space (`forwardWindows(of:to:)`, #1655) forgets its
    /// sizes under its `sizingOwner` alone, since a same-named Space
    /// of another arrangement is another Space (#1230). A switch's
    /// prune forgets nothing: the Space returns with its arrangement
    /// (ruling 5).
    func forgetDroppedSessionRatios(of space: SpaceID) {
        guard desktopMemory.installing?.switching != true else { return }
        let owner = sizingOwner(of: space)
        mapSessionRatios { arrangement, id, ratios in
            if id == space, arrangement == owner { ratios = SessionRatios() }
        }
    }

    /// A renumbered Space keeps its sizes under `owner`, the
    /// arrangement the hold records (`moveMembers`, #1655) — at a
    /// hold the live one, which `sizingOwner` no longer names once
    /// an apply installs another.
    func rekeySessionRatios(
        _ old: SpaceID,
        to new: SpaceID,
        under owner: HeldOrigin.Arrangement?
    ) {
        desktopMemory.sessionRatios = desktopMemory.sessionRatios
            .mapValues { byArrangement in
                var out = byArrangement
                if var sizes = out[owner],
                    let ratios = sizes.removeValue(forKey: old)
                {
                    sizes[new] = ratios
                    out[owner] = sizes
                }
                return out
            }
    }

    /// A renamed profile keeps its sizes; a deleted one forgets them.
    func rekeySessionRatios(
        profile old: String,
        to new: String
    ) {
        let from = HeldOrigin.Arrangement.profile(old)
        desktopMemory.sessionRatios = desktopMemory.sessionRatios
            .mapValues { byArrangement in
                var out = byArrangement
                if let sizes = out.removeValue(forKey: from) {
                    out[.profile(new)] = sizes
                }
                return out
            }
    }

    private func mapSessionRatios(
        _ body: (HeldOrigin.Arrangement?, SpaceID, inout SessionRatios)
            -> Void
    ) {
        desktopMemory.sessionRatios = desktopMemory.sessionRatios
            .mapValues { byArrangement in
                var kept:
                    [HeldOrigin.Arrangement?: DesktopMemory.SpaceRatios] =
                        [:]
                for (arrangement, sizes) in byArrangement {
                    var out: DesktopMemory.SpaceRatios = [:]
                    for (space, ratios) in sizes {
                        var ratios = ratios
                        body(arrangement, space, &ratios)
                        if ratios != SessionRatios() { out[space] = ratios }
                    }
                    if !out.isEmpty { kept[arrangement] = out }
                }
                return kept
            }
            .filter { !$0.value.isEmpty }
    }

    // MARK: - The in-place restart's carry (#930)

    /// `space`'s sizes for the in-place capture: every entry, and
    /// the set it draws now.
    func sessionSizing(of space: SpaceID) -> StateSnapshot.SessionSizing {
        StateSnapshot.SessionSizing(
            entries: sessionRatioEntries(of: space),
            drawn: sessionRatios(of: space)
        )
    }

    private func sessionRatioEntries(
        of space: SpaceID
    ) -> [SessionSizingKey: SessionRatios] {
        var out: [SessionSizingKey: SessionRatios] = [:]
        for (desktop, byArrangement) in desktopMemory.sessionRatios {
            for (arrangement, sizes) in byArrangement {
                if let ratios = sizes[space] {
                    out[
                        SessionSizingKey(
                            desktop: desktop,
                            arrangement: arrangement
                        )
                    ] =
                        ratios
                }
            }
        }
        return out
    }

    /// Takes back what `sessionRatioEntries` captured, after the
    /// replay re-stated the Space's mode. `oneEntry` is an older
    /// build's one set per Space, which lands where the Space is
    /// drawn now.
    func adoptSessionRatios(
        _ entries: [SessionSizingKey: SessionRatios],
        oneEntry: SessionRatios?,
        of space: SpaceID
    ) {
        guard state.workspaces[space] != nil else { return }
        if let oneEntry {
            withSessionRatios(of: space) { $0 = oneEntry }
            return
        }
        for (key, ratios) in entries where ratios != SessionRatios() {
            setSizes(at: key) { $0[space] = ratios }
        }
    }
}
