import CoreGraphics

/// Proportional re-anchoring for floating windows crossing displays
/// (`FloatNudge`, #444). Who is eligible is `EffectiveFloat`'s
/// question, not this type's (#1178).
public enum FloatReanchor {
    /// Computes target frame proportionally repositioned and optionally scaled
    /// (`FloatNudge.confine`,
    /// `TilingSettings.floatScaleOnDisplayChange`, #502).
    public static func target(
        frame: CGRect,
        from source: CGRect,
        to target: CGRect,
        scaleSize: Bool = false
    ) -> CGRect {
        let relX =
            source.width > 0
            ? (frame.midX - source.minX) / source.width
            : 0.5
        let relY =
            source.height > 0
            ? (frame.midY - source.minY) / source.height
            : 0.5
        let width =
            scaleSize && source.width > 0
            ? frame.width * target.width / source.width
            : frame.width
        let height =
            scaleSize && source.height > 0
            ? frame.height * target.height / source.height
            : frame.height
        let moved = CGRect(
            x: target.minX + relX * target.width - width / 2,
            y: target.minY + relY * target.height - height / 2,
            width: width,
            height: height
        )
        return FloatNudge.confine(moved, to: target)
    }
}
