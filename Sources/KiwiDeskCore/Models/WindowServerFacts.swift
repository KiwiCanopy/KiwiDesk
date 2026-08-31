import CoreGraphics

/// Empirical WindowServer placement limits and constants (#139, #148).
public enum WindowServerFacts {
    /// WindowServer minimum on-screen visibility floor in pt (#142, #148).
    public static let visibilityFloor: CGFloat = 40
}
