import CoreGraphics

/// A tiled sticky traveler entering a floating-mode space on
/// another display takes the frame it was last drawn with, moved
/// onto that display proportionally (#1217, `FloatReanchor`).
public enum TravelerRehome {
    /// The frame `frame` takes on `destination`, or nil when the
    /// screen it mostly sits on IS the destination, or none.
    public static func target(
        frame: CGRect,
        screens: [CGRect],
        destination: CGRect,
        scaleSize: Bool
    ) -> CGRect? {
        guard
            let source =
                screens
                .filter({ overlap($0, frame) > 0 })
                .max(by: { overlap($0, frame) < overlap($1, frame) }),
            source != destination
        else { return nil }
        return FloatReanchor.target(
            frame: frame,
            from: source,
            to: destination,
            scaleSize: scaleSize
        )
    }

    private static func overlap(
        _ screen: CGRect,
        _ frame: CGRect
    ) -> CGFloat {
        let shared = screen.intersection(frame)
        return shared.isNull ? 0 : shared.width * shared.height
    }
}
