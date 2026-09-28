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

    /// Drag one of two windows onto another Space's item (#1726,
    /// owner-reviewed as an HTML animation): it lifts off whole and
    /// its half of the screen is simply empty while it travels; on
    /// the drop it shrinks to the item's box, fading on the way, and
    /// the window left behind fills the screen — the rest frame.
    struct DropOnSpace: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let lift = gestureStage(t, 0.03, 0.15)
            let carry = gestureEase(gestureStage(t, 0.15, 0.55))
            let shrink = gestureEase(gestureStage(t, 0.58, 0.72))
            let fade = gestureStage(t, 0.64, 0.74)
            let fill = gestureEase(gestureStage(t, 0.75, 0.9))
            // The pointer holds the window by its title area; on the
            // drop it shrinks onto the item's own box.
            let grab = CGPoint(
                x: gestureLerp(86, 43, carry),
                y: gestureLerp(32, 8, carry)
            )
            let item = CGRect(x: 32, y: 3, width: 22, height: 10)
            ZStack(alignment: .topLeading) {
                ink.window(CGRect(x: 10, y: 24, width: 48, height: 42))
                    .opacity(1 - fill)
                ink.window(CGRect(x: 10, y: 24, width: 100, height: 42))
                    .opacity(fill)
                ink.window(CGRect(x: 62, y: 24, width: 48, height: 42))
                    .opacity(1 - lift)
                ink.shelf()
                ink.activeItem(
                    CGRect(x: 6, y: 3, width: 22, height: 10),
                    label: "1"
                )
                ink.item(item, label: "2")
                ink.item(
                    CGRect(x: 58, y: 3, width: 22, height: 10),
                    label: "3"
                )
                ink.ghost(
                    CGRect(
                        x: gestureLerp(grab.x - 24, item.minX, shrink),
                        y: gestureLerp(grab.y - 8, item.minY, shrink),
                        width: gestureLerp(48, item.width, shrink),
                        height: gestureLerp(42, item.height, shrink)
                    )
                )
                .opacity(lift * (1 - fade))
                ink.pointer(at: grab)
            }
        }
    }

    /// Hold a dragged window over another Space (#1726, owner-
    /// reviewed as an HTML animation): Space 1 keeps its other
    /// window, the dragged one's half simply empty; the ring fills;
    /// the screen becomes Space 2 — BSP, two windows and an empty
    /// gap; still dragging, the window goes down into the gap and
    /// fills it — the rest frame.
    struct Spring: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let grab = gestureStage(t, 0.02, 0.12)
            let carry = gestureEase(gestureStage(t, 0.12, 0.35))
            let hold = gestureStage(t, 0.35, 0.62)
            let open = gestureEase(gestureStage(t, 0.62, 0.72))
            let down = gestureEase(gestureStage(t, 0.72, 0.88))
            let drop = gestureStage(t, 0.88, 0.96)
            let pointer = CGPoint(
                x: gestureLerp(gestureLerp(86, 43, carry), 86, down),
                y: gestureLerp(gestureLerp(32, 8, carry), 54, down)
            )
            let height = gestureLerp(42, 20, down)
            let first = CGRect(x: 6, y: 3, width: 22, height: 10)
            let second = CGRect(x: 32, y: 3, width: 22, height: 10)
            ZStack(alignment: .topLeading) {
                Group {
                    ink.window(CGRect(x: 10, y: 24, width: 48, height: 42))
                    ink.window(CGRect(x: 62, y: 24, width: 48, height: 42))
                        .opacity(1 - grab)
                }
                .opacity(1 - open)
                Group {
                    ink.window(CGRect(x: 10, y: 24, width: 48, height: 42))
                    ink.window(CGRect(x: 62, y: 24, width: 48, height: 20))
                    ink.window(CGRect(x: 62, y: 46, width: 48, height: 20))
                        .opacity(drop)
                }
                .opacity(open)
                ink.shelf()
                ink.item(first, label: "1")
                ink.activeItem(first, label: "1").opacity(1 - open)
                ink.item(second, label: "2")
                ink.activeItem(second, label: "2").opacity(open)
                Circle()
                    .trim(from: 0, to: hold)
                    .stroke(ink.accent, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
                    .offset(x: 32, y: -3)
                    .opacity(hold > 0 ? 1 - open : 0)
                ink.ghost(
                    CGRect(
                        x: pointer.x - 24,
                        y: pointer.y - 8,
                        width: 48,
                        height: height
                    )
                )
                .opacity(grab * (1 - drop))
                ink.pointer(at: pointer)
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
