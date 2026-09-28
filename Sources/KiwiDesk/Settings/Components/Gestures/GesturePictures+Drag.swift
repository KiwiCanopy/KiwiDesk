import SwiftUI

/// The two drag stories (#1726), split from `GesturePictures` for
/// size. Same contract: `t` runs 0 → 1, 1 is the key frame, and a
/// story runs at `GesturePace.story`.
extension GesturePicture {
    /// Drag one of two windows onto another Space's item: it lifts
    /// off whole and its half of the screen is simply empty while it
    /// travels; on
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

    /// Hold a dragged window over another Space: Space 1 keeps its
    /// other window, the dragged one's half simply empty; the ring
    /// fills;
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
}
