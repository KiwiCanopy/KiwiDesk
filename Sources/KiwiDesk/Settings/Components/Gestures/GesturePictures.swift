import SwiftUI

/// The Mouse & trackpad pictures (#1726). Each takes the gesture's
/// phase `t`, 0 → 1, and rests on its key frame at 1 — the frame
/// Reduce Motion shows. Coordinates are the 120 × 72 plate's.
enum GesturePicture {
    /// Drag a window onto another: the ghost lands on the target.
    struct Swap: View {
        let t: CGFloat
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
    struct Edge: View {
        let t: CGFloat
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

    /// The pointer follows focus to the window that took it.
    struct FollowFocus: View {
        let t: CGFloat
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            ZStack(alignment: .topLeading) {
                ink.window(CGRect(x: 8, y: 10, width: 50, height: 52))
                ink.window(CGRect(x: 62, y: 10, width: 50, height: 52))
                ink.target(CGRect(x: 62, y: 10, width: 50, height: 52))
                ink.pointer(
                    at: CGPoint(
                        x: gestureLerp(30, 86, t),
                        y: gestureLerp(44, 34, t)
                    )
                )
            }
        }
    }

    /// Drag a window up onto a Space item on the shelf.
    struct DropOnSpace: View {
        let t: CGFloat
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let x = gestureLerp(46, 30, t)
            let y = gestureLerp(40, 4, t)
            ZStack(alignment: .topLeading) {
                ink.shelf()
                ink.item(
                    CGRect(x: 6, y: 3, width: 22, height: 10),
                    label: "1"
                )
                ink.item(
                    CGRect(x: 32, y: 3, width: 22, height: 10),
                    label: "2"
                )
                ink.item(
                    CGRect(x: 58, y: 3, width: 22, height: 10),
                    label: "3"
                )
                ink.target(
                    CGRect(x: 32, y: 3, width: 22, height: 10)
                )
                ink.window(CGRect(x: 10, y: 24, width: 100, height: 42))
                ink.ghost(CGRect(x: x, y: y, width: 26, height: 18))
                ink.pointer(at: CGPoint(x: x + 13, y: y + 6))
            }
        }
    }

    /// Hold over the Space: the delay fills, then it opens.
    struct Spring: View {
        let t: CGFloat
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            ZStack(alignment: .topLeading) {
                ink.shelf()
                ink.item(
                    CGRect(x: 6, y: 3, width: 22, height: 10),
                    label: "1"
                )
                ink.item(
                    CGRect(x: 32, y: 3, width: 22, height: 10),
                    label: "2"
                )
                Circle()
                    .trim(from: 0, to: t)
                    .stroke(ink.accent, lineWidth: 2)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
                    .offset(x: 32, y: -3)
                ink.window(CGRect(x: 10, y: 24, width: 48, height: 42))
                ink.ghost(CGRect(x: 62, y: 24, width: 48, height: 42))
                    .opacity(t)
                ink.pointer(at: CGPoint(x: 43, y: 8))
            }
        }
    }

    /// Scroll over the shelf: the run slides past its edge.
    struct ShelfScroll: View {
        let t: CGFloat
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
    struct AppBarReorder: View {
        let t: CGFloat
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let x = gestureLerp(8, 46, t)
            ZStack(alignment: .topLeading) {
                ink.window(CGRect(x: 10, y: 6, width: 100, height: 42))
                ink.shelf(y: 56)
                ink.item(CGRect(x: 6, y: 59, width: 30, height: 10))
                ink.item(CGRect(x: 42, y: 59, width: 30, height: 10))
                ink.item(CGRect(x: 78, y: 59, width: 30, height: 10))
                ink.ghost(CGRect(x: x, y: 57, width: 26, height: 14))
                ink.pointer(at: CGPoint(x: x + 13, y: 62))
            }
        }
    }
}
