import AppKit

/// The core's one WindowServer stream (#2275): constructed with
/// the ring's manager, and the door every other consumer — the
/// sticky mark, KiwiVision's plate — registers through.
extension KiwiCore {
    public var windowServer: WindowServerWatch { borders.watch }

    /// Connects the sticky mark and KiwiVision's plate, Core to
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
        // After the ring's own re-order: the plate stacks under it.
        windowServer.connect(
            .vision,
            WindowServerWatch.Hooks(
                restack: { [weak self] id in
                    self?.visionWindowRestacked(id)
                }
            )
        )
        stickyMarks.isWindowServerTracked = { [weak self] id in
            self?.windowServer.hears(id, as: .mark) ?? false
        }
    }
}
