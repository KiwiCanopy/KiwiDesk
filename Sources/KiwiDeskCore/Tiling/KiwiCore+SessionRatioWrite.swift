import Foundation

/// The interactive-resize ratio write seam (#458): an authored
/// config override of the field takes the write (pre-#458
/// behavior — the #290 editor's value stays live); otherwise
/// the value lands in the space's session layer, never the
/// global. Both the keyboard `resize` verb and the mouse-drag
/// drop (`applyResizeAdjustment`) route here.
extension KiwiCore {
    func writeSplitRatioH(_ value: Double, for space: SpaceID) {
        if tiler.settings.setSplitRatioH(value, for: space) {
            return
        }
        state.workspaces.withSpace(space) {
            $0.sessionRatios.splitRatioH = value
        }
    }

    func writeSplitRatioV(_ value: Double, for space: SpaceID) {
        if tiler.settings.setSplitRatioV(value, for: space) {
            return
        }
        state.workspaces.withSpace(space) {
            $0.sessionRatios.splitRatioV = value
        }
    }

    func writeMasterRatio(_ value: Double, for space: SpaceID) {
        if tiler.settings.setMasterRatio(value, for: space) {
            return
        }
        state.workspaces.withSpace(space) {
            $0.sessionRatios.masterRatio = value
        }
    }

    func writeSlotSize(_ value: ScrollSize, for space: SpaceID) {
        if tiler.settings.setSlotSize(value, for: space) {
            return
        }
        state.workspaces.withSpace(space) {
            $0.sessionRatios.slotSize = value
        }
    }

    /// Clears one session field on every space — the explicit
    /// global setters (`bsp.set_ratio_h`, `stack.set_master_
    /// ratio`, `scroll.set_slot_size`) call this so an explicit
    /// config write visibly applies everywhere instead of being
    /// shadowed by earlier interactive resizes (the #383
    /// "visibly did nothing" trap, session-layer edition).
    func clearSessionRatios(
        _ clear: (inout SessionRatios) -> Void
    ) {
        for space in state.workspaces.allSpaces {
            state.workspaces.withSpace(space.id) {
                clear(&$0.sessionRatios)
            }
        }
    }
}
