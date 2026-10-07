import SwiftUI

/// The Space Bar glyph pictures (#1726 entries for #1528's click
/// targets, #1946's hover peek and #1514's hover title). Same contract as
/// `GesturePicture`: `t` runs 0 → 1 and 1 is the key frame.
extension GesturePicture {
    /// Click an app glyph: a press, then the focus ring moves onto
    /// it — its Space shown, its window focused. The pointer is
    /// already there; a click does not travel.
    struct GlyphClick: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let moved = gestureStage(t, 0.45, 0.6)
            ZStack(alignment: .topLeading) {
                ink.shelf()
                ink.item(CGRect(x: 4, y: 3, width: 64, height: 10))
                ink.label("2", at: CGPoint(x: 8, y: 3))
                ink.glyph(at: CGPoint(x: 26, y: 8))
                ink.glyph(at: CGPoint(x: 38, y: 8))
                ink.glyph(at: CGPoint(x: 38, y: 8), focused: true)
                    .opacity(1 - moved)
                ink.glyph(at: CGPoint(x: 50, y: 8))
                ink.glyph(at: CGPoint(x: 50, y: 8), focused: true)
                    .opacity(moved)
                ink.press(at: CGPoint(x: 50, y: 8), t)
                ink.pointer(at: CGPoint(x: 50, y: 8))
            }
        }
    }

    /// Point at an app glyph or `+n` (#1946): after a beat its
    /// windows show beside the bar, the pointer crosses onto one
    /// and clicks it — the row the click picks ringed.
    struct GlyphPeek: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        /// The peek: its app line on top and the glyph's three
        /// window rows, as its badge counts.
        private static let peek = CGRect(x: 22, y: 22, width: 86, height: 38)
        /// The second line of the peek, the one the pointer picks.
        private static let row = CGRect(x: 25, y: 33, width: 66, height: 7)

        var body: some View {
            let ink = GestureInk(palette: palette)
            let reach = gestureStage(t, 0.5, 0.7)
            ZStack(alignment: .topLeading) {
                ink.shelf()
                ink.item(CGRect(x: 4, y: 3, width: 76, height: 10))
                ink.label("2", at: CGPoint(x: 8, y: 3))
                ink.glyph(at: CGPoint(x: 26, y: 8))
                ink.glyph(at: CGPoint(x: 38, y: 8), focused: true)
                ink.label("3", at: CGPoint(x: 41, y: 1))
                ink.label("+2", at: CGPoint(x: 52, y: 3))
                ink.panel(Self.peek, rows: 4, titled: true)
                    .opacity(gestureStage(t, 0.3, 0.45))
                ink.target(Self.row, radius: 2)
                    .opacity(gestureStage(t, 0.7, 0.8))
                ink.press(
                    at: CGPoint(x: 40, y: Self.row.midY),
                    gestureStage(t, 0.6, 1)
                )
                ink.pointer(
                    at: CGPoint(
                        x: gestureLerp(
                            gestureLerp(64, 38, gestureStage(t, 0, 0.25)),
                            40,
                            reach
                        ),
                        y: gestureLerp(8, Self.row.midY, reach)
                    )
                )
            }
        }
    }

    /// Point at an App Bar item whose title is cut: the pointer
    /// arrives, and after a beat the whole title shows (#1514).
    struct AppBarHover: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            ZStack(alignment: .topLeading) {
                ink.window(CGRect(x: 10, y: 6, width: 100, height: 30))
                ink.shelf(y: 56)
                ink.item(CGRect(x: 6, y: 59, width: 34, height: 10))
                ink.item(CGRect(x: 44, y: 59, width: 34, height: 10))
                ink.label("…", at: CGPoint(x: 70, y: 58))
                ink.item(CGRect(x: 82, y: 59, width: 30, height: 10))
                ink.panel(
                    CGRect(x: 18, y: 38, width: 92, height: 16),
                    rows: 1,
                    titled: true
                )
                .opacity(gestureStage(t, 0.6, 0.75))
                ink.pointer(
                    at: CGPoint(
                        x: gestureLerp(100, 60, gestureStage(t, 0, 0.35)),
                        y: 63
                    )
                )
            }
        }
    }

    /// Right-click a Space on the shelf: the press, then its menu
    /// opens beneath it (#1518).
    struct ContextMenu: View, Animatable {
        var t: CGFloat
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            ZStack(alignment: .topLeading) {
                ink.shelf()
                ink.item(CGRect(x: 4, y: 3, width: 44, height: 10))
                ink.label("1", at: CGPoint(x: 8, y: 3))
                ink.glyph(at: CGPoint(x: 26, y: 8), focused: true)
                ink.glyph(at: CGPoint(x: 38, y: 8))
                ink.item(CGRect(x: 52, y: 3, width: 32, height: 10))
                ink.label("2", at: CGPoint(x: 56, y: 3))
                ink.press(at: CGPoint(x: 12, y: 8), t)
                ink.panel(
                    CGRect(x: 10, y: 20, width: 74, height: 44),
                    rows: 4
                )
                .opacity(gestureStage(t, 0.45, 0.6))
                ink.pointer(at: CGPoint(x: 14, y: 10))
            }
        }
    }
}
