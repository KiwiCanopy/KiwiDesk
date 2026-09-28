import SwiftUI

/// The Mouse & trackpad pictures (#1726). Each takes the gesture's
/// phase `t`, 0 → 1, and rests on its key frame at 1 — the frame
/// Reduce Motion shows. Coordinates are the 120 × 72 plate's.
enum GesturePicture {
    /// Drag a window onto another: the ghost lands on the target.
    struct Swap: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let x = gestureLerp(14, 68, t)
            ZStack(alignment: .topLeading) {
                ink.window(CGRect(x: 8, y: 10, width: 50, height: 52))
                ink.window(CGRect(x: 62, y: 10, width: 50, height: 52))
                ink.target(CGRect(x: 62, y: 10, width: 50, height: 52))
                ink.ghost(CGRect(x: x, y: 20, width: 38, height: 30))
                ink.pointer(at: CGPoint(x: x + 20, y: 34))
            }
        }
    }

    /// Drag an edge: one window grows as its neighbour gives way.
    struct Edge: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let edge = gestureLerp(60, 74, t)
            ZStack(alignment: .topLeading) {
                ink.window(
                    CGRect(x: 8, y: 10, width: edge - 10, height: 52)
                )
                ink.window(
                    CGRect(
                        x: edge + 2,
                        y: 10,
                        width: 110 - edge,
                        height: 52
                    )
                )
                Rectangle()
                    .fill(ink.ink.opacity(0.35))
                    .frame(width: 1, height: 56)
                    .offset(x: 60, y: 8)
                Capsule()
                    .fill(ink.accent)
                    .frame(width: 3, height: 24)
                    .offset(x: edge - 0.5, y: 24)
                ink.pointer(at: CGPoint(x: edge + 1, y: 34))
            }
        }
    }

    /// Focus moves first; then the pointer jumps to the window
    /// that took it, in one frame, the way the warp does.
    struct FollowFocus: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let focus = gestureStage(t, 0.15, 0.4)
            let left = CGRect(x: 8, y: 10, width: 50, height: 52)
            let right = CGRect(x: 62, y: 10, width: 50, height: 52)
            ZStack(alignment: .topLeading) {
                ink.window(left)
                ink.window(right)
                ink.target(left).opacity(1 - focus)
                ink.target(right).opacity(focus)
                ink.pointer(
                    at: t < 0.6
                        ? CGPoint(x: 30, y: 34) : CGPoint(x: 86, y: 34)
                )
            }
        }
    }

    /// Scroll over the shelf: the run slides past its edge.
    struct ShelfScroll: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let shift = gestureLerp(0, -26, t)
            ZStack(alignment: .topLeading) {
                ink.shelf()
                ForEach(0..<5) { index in
                    ink.item(
                        CGRect(
                            x: 6 + CGFloat(index) * 26 + shift,
                            y: 3,
                            width: 22,
                            height: 10
                        ),
                        label: "\(index + 1)"
                    )
                }
                ink.cue("arrow.left", at: CGPoint(x: 54, y: 30))
                ink.window(CGRect(x: 10, y: 44, width: 100, height: 22))
            }
        }
    }

    /// Drag an App Bar item along the bar to reorder it.
    struct AppBarReorder: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            // The dragged item leaves its slot; as it passes its
            // neighbour, the neighbour slides into the slot it left.
            let x = gestureLerp(6, 42, gestureStage(t, 0.05, 0.7))
            let shift = gestureStage(t, 0.35, 0.55)
            ZStack(alignment: .topLeading) {
                ink.window(CGRect(x: 10, y: 6, width: 100, height: 42))
                ink.shelf(y: 56)
                ink.item(
                    CGRect(
                        x: gestureLerp(42, 6, shift),
                        y: 59,
                        width: 30,
                        height: 10
                    )
                )
                ink.item(CGRect(x: 78, y: 59, width: 30, height: 10))
                ink.ghost(CGRect(x: x, y: 57, width: 30, height: 14))
                ink.pointer(at: CGPoint(x: x + 15, y: 62))
            }
        }
    }
}
