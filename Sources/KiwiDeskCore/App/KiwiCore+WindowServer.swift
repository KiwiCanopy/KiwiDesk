import AppKit

/// The core's one WindowServer stream (#2275): constructed with
/// the ring's manager, and the door every other consumer — the
/// sticky mark, KiwiVision's float veils and plate — registers
/// through.
extension KiwiCore {
    public var windowServer: WindowServerWatch { borders.watch }

    /// Connects the sticky mark and KiwiVision's veils, Core to
    /// Core and touching no machine, so a test core runs the real
    /// fan-out. The ring connects itself in `BorderManager.init`.
    func connectWindowServerConsumers() {
        // The mark rides the WindowServer bounds stream — AX move
        // echoes alone lag during drags — and a reorder re-asserts
        // its stacking on a raise that fires no AX focus event.
        windowServer.connect(
            .mark,
            WindowServerWatch.Hooks(
                frame: { [weak self] id, frame, _ in
                    self?.stickyMarks.reposition(id, windowFrame: frame)
                },
                restack: { [weak self] id in
                    self?.stickyMarks.reassert(id)
                }
            )
        )
        // After the mark's and the ring's re-order: a float's veil
        // goes back above them (#2103 ruling 3).
        windowServer.connect(
            .floatDim,
            WindowServerWatch.Hooks(
                frame: { [weak self] id, frame, _ in
                    self?.floatDims.reposition(id, windowFrame: frame)
                },
                restack: { [weak self] id in
                    self?.floatDims.restack(id)
                },
                hide: { [weak self] id in
                    self?.floatDims.hideWindow(id)
                }
            )
        )
        floatDims.isWindowServerTracked = { [weak self] id in
            self?.windowServer.hears(id, as: .floatDim) ?? false
        }
        // After the ring's own re-order: the plate stacks under it.
        windowServer.connect(
            .vision,
            WindowServerWatch.Hooks(
                restack: { [weak self] id in
                    self?.visionTargetRestacked(id)
                }
            )
        )
        stickyMarks.isWindowServerTracked = { [weak self] id in
            self?.windowServer.hears(id, as: .mark) ?? false
        }
    }
}
