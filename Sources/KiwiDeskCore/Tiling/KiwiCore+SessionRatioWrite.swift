import Foundation

/// The interactive-resize ratio seam (#458, #764): the value lands
/// in the session layer — never the global, never the authored
/// override, which keeps the number the profile or `init.lua`
/// wrote so `reset_layout_sizing` can return to it. Both the
/// keyboard `resize` verb and the mouse-drag drop
/// (`applyResizeAdjustment`) route here. The layer is per macOS
/// Desktop (#2921): `DesktopMemory.sessionRatios`, read through
/// `sessionRatios(of:)` alone, which every resolver overlay takes
/// as a required argument (`SessionRatioSeamTests`).
extension KiwiCore {
    /// The store key for `space` now: the Desktop its screen
    /// shows, else the one shared entry (no SkyLight, a screen no
    /// switch has filed yet — owner ruling 3, #2921).
    private func sizingDesktop(of space: SpaceID) -> SkyLight.SpaceID? {
        guard case .shown(let desktop) = shownDesktop(of: space) else {
            return nil
        }
        return desktop
    }

    /// The sizes a resize wrote for `space` on the Desktop shown
    /// now — the ONE read door. A Desktop not sized yet answers
    /// empty, so the overlay falls through to the override, then
    /// the global value.
    func sessionRatios(of space: SpaceID) -> SessionRatios {
        desktopMemory.sessionRatios[sizingDesktop(of: space)]?[space]
            ?? SessionRatios()
    }

    /// Mutates `space`'s sizes on the Desktop shown now; an entry
    /// left empty is dropped.
    func withSessionRatios(
        of space: SpaceID,
        _ body: (inout SessionRatios) -> Void
    ) {
        guard state.workspaces[space] != nil else { return }
        let desktop = sizingDesktop(of: space)
        var sizes = desktopMemory.sessionRatios[desktop] ?? [:]
        var ratios = sizes[space] ?? SessionRatios()
        body(&ratios)
        sizes[space] = ratios == SessionRatios() ? nil : ratios
        desktopMemory.sessionRatios[desktop] = sizes.isEmpty ? nil : sizes
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

    // MARK: - Clearing doors

    /// Clears one session field on every Space and every Desktop —
    /// the explicit global setters (`bsp.set_ratio_h`, `stack.set_
    /// master_ratio`, `scroll.set_slot_size`) and a config load call
    /// this so an explicit config write visibly
    /// applies everywhere instead of being shadowed by earlier
    /// interactive resizes (the #383 "visibly did nothing" trap,
    /// session-layer edition).
    func clearSessionRatios(
        _ clear: (inout SessionRatios) -> Void
    ) {
        mapSessionRatios { _, ratios in clear(&ratios) }
    }

    /// The per-space `_override` setters' sibling: the layer
    /// outranks the override, so an explicit write on one Space
    /// drops that Space's shadow on every Desktop (#764, #2921
    /// ruling 4).
    func clearSessionRatios(
        for space: SpaceID,
        _ clear: (inout SessionRatios) -> Void
    ) {
        mapSessionRatios { id, ratios in
            if id == space { clear(&ratios) }
        }
    }

    /// `reset_layout_sizing <space>`: that Space on the Desktop
    /// shown now only (#2921 ruling 2).
    func resetSessionRatios(of space: SpaceID) {
        withSessionRatios(of: space) { $0 = SessionRatios() }
    }

    /// A dropped Space forgets its sizes on every Desktop
    /// (`forwardWindows(of:to:)`, #1655).
    func forgetSessionRatios(of space: SpaceID) {
        clearSessionRatios(for: space) { $0 = SessionRatios() }
    }

    /// A renumbered Space keeps its sizes (`moveMembers`, #1655).
    func rekeySessionRatios(_ old: SpaceID, to new: SpaceID) {
        desktopMemory.sessionRatios = desktopMemory.sessionRatios
            .mapValues {
                var sizes = $0
                if let ratios = sizes.removeValue(forKey: old) {
                    sizes[new] = ratios
                }
                return sizes
            }
    }

    private func mapSessionRatios(
        _ body: (SpaceID, inout SessionRatios) -> Void
    ) {
        desktopMemory.sessionRatios = desktopMemory.sessionRatios
            .mapValues { sizes in
                var out: DesktopMemory.SpaceRatios = [:]
                for (space, ratios) in sizes {
                    var ratios = ratios
                    body(space, &ratios)
                    if ratios != SessionRatios() { out[space] = ratios }
                }
                return out
            }
            .filter { !$0.value.isEmpty }
    }

    // MARK: - The in-place restart's carry (#930)

    /// Every Desktop's sizes for `space`, for the in-place capture.
    func sessionRatioEntries(
        of space: SpaceID
    ) -> [SkyLight.SpaceID?: SessionRatios] {
        desktopMemory.sessionRatios.compactMapValues { $0[space] }
    }

    /// Takes back what `sessionRatioEntries` captured, after the
    /// replay re-stated the Space's mode.
    func adoptSessionRatios(
        _ entries: [SkyLight.SpaceID?: SessionRatios],
        of space: SpaceID
    ) {
        guard state.workspaces[space] != nil else { return }
        for (desktop, ratios) in entries where ratios != SessionRatios() {
            desktopMemory.sessionRatios[desktop, default: [:]][space] =
                ratios
        }
    }
}
