import Foundation

/// The interactive-resize ratio write seam (#458, #764): the
/// value lands in the space's session layer — never the global,
/// never the authored override, which keeps the number the
/// profile or `init.lua` wrote so `reset_layout_sizing` can
/// return to it. Both the keyboard `resize` verb and the
/// mouse-drag drop (`applyResizeAdjustment`) route here.
extension KiwiCore {
    func writeSplitRatioH(_ value: Double, for space: SpaceID) {
        state.workspaces.withSpace(space) {
            $0.sessionRatios.splitRatioH = value
        }
    }

    func writeSplitRatioV(_ value: Double, for space: SpaceID) {
        state.workspaces.withSpace(space) {
            $0.sessionRatios.splitRatioV = value
        }
    }

    func writeMasterRatio(_ value: Double, for space: SpaceID) {
        state.workspaces.withSpace(space) {
            $0.sessionRatios.masterRatio = value
        }
    }

    func writeSlotSize(_ value: ScrollSize, for space: SpaceID) {
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

    /// The per-space `_override` setters' sibling: the layer
    /// outranks the override, so an explicit write on one Space
    /// drops that Space's shadow (#764). `SessionRatioSeamTests`
    /// holds every `sessionRatios` write outside this file to
    /// the model's own reseeds.
    func clearSessionRatios(
        for space: SpaceID,
        _ clear: (inout SessionRatios) -> Void
    ) {
        state.workspaces.withSpace(space) {
            clear(&$0.sessionRatios)
        }
    }
}
