/// The one door a state change (#2676) holds its window's ring
/// through: floating and back, maximizing and back, out of the
/// pocket. Called after the write, so only a window our spring
/// now moves is held; an instant write keeps its leading ring.
extension KiwiCore {
    func holdRingForStateChange(_ id: WindowID) {
        guard tiler.animation.isAnimating(window: id) else { return }
        borders.holdStateChange(
            of: id,
            target: tiler.commandedFrame(of: id)
        )
    }
}
