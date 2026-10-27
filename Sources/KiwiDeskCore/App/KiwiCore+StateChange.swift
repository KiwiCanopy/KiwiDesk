/// The one door a state change (#2676) holds its window's ring
/// through: floating and back, maximizing and back. Called after
/// the write, so only a window our spring now moves is held; an
/// instant write keeps its leading ring. A take-out holds its own
/// through the brief pocket's landing (#2680).
extension KiwiCore {
    func holdRingForStateChange(_ id: WindowID) {
        guard tiler.animation.isAnimating(window: id) else { return }
        borders.holdStateChange(
            of: id,
            target: tiler.commandedFrame(of: id)
        )
    }
}
