import CoreGraphics

extension FrameApplier {
    /// The screen whose bottom band a sized write ending near it
    /// must clear (#2894); the window's own frame, read on its
    /// queue, decides whether it shrinks.
    func bandScreen(_ frame: CGRect, setSize: Bool) -> CGRect? {
        guard setSize else { return nil }
        return BottomBandWrite.screen(for: frame, among: screenFrames())
    }
}
