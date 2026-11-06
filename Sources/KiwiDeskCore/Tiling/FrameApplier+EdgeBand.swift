import CoreGraphics

extension FrameApplier {
    /// The band a sized write ending near it must clear (#2894,
    /// #2966); the window's own frame, read on its queue, decides
    /// whether it shrinks.
    func edgeBand(_ frame: CGRect, setSize: Bool) -> EdgeBand? {
        guard setSize else { return nil }
        return EdgeBandWrite.band(
            for: frame,
            among: EdgeBandWrite.bands(
                of: screenFrames(),
                for: frame,
                separateSpaces: separateSpaces()
            )
        )
    }
}
