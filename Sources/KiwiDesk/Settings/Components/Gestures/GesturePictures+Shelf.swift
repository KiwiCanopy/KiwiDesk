import SwiftUI

/// The Space Bar glyph pictures (#1726 entries for #1528's click
/// targets and #1514's hover title). Same contract as
/// `GesturePicture`: `t` runs 0 → 1 and 1 is the key frame.
extension GesturePicture {
    /// Click an app glyph that carries a window count: a press,
    /// then its windows open as a menu (a one-window glyph just
    /// focuses). The pointer is already there — a click does not
    /// travel.
    struct GlyphClick: View, Animatable {
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
                ink.item(CGRect(x: 4, y: 3, width: 64, height: 10))
                ink.label("2", at: CGPoint(x: 8, y: 3))
                ink.glyph(at: CGPoint(x: 26, y: 8))
                ink.glyph(at: CGPoint(x: 38, y: 8), focused: true)
                ink.label("3", at: CGPoint(x: 41, y: 1))
                ink.glyph(at: CGPoint(x: 52, y: 8))
                ink.press(at: CGPoint(x: 38, y: 8), t)
                ink.panel(
                    CGRect(x: 30, y: 20, width: 64, height: 34),
                    rows: 3
                )
                .opacity(gestureStage(t, 0.45, 0.6))
                ink.pointer(at: CGPoint(x: 38, y: 8))
            }
        }
    }

    /// Click `+n`: a menu of the windows the item did not draw.
    struct OverflowMenu: View, Animatable {
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
                ink.item(CGRect(x: 4, y: 3, width: 76, height: 10))
                ink.glyph(at: CGPoint(x: 14, y: 8), focused: true)
                ink.glyph(at: CGPoint(x: 26, y: 8))
                ink.glyph(at: CGPoint(x: 38, y: 8))
                ink.label("+3", at: CGPoint(x: 48, y: 3))
                ink.press(at: CGPoint(x: 54, y: 8), t)
                ink.panel(
                    CGRect(x: 40, y: 20, width: 70, height: 44),
                    rows: 4
                )
                .opacity(gestureStage(t, 0.45, 0.6))
                ink.pointer(at: CGPoint(x: 58, y: 10))
            }
        }
    }

    /// Point at an app glyph: the pointer arrives, and after a
    /// beat its app and window titles show.
    struct GlyphHover: View, Animatable {
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
                ink.item(CGRect(x: 4, y: 3, width: 64, height: 10))
                ink.label("2", at: CGPoint(x: 8, y: 3))
                ink.glyph(at: CGPoint(x: 26, y: 8))
                ink.glyph(at: CGPoint(x: 38, y: 8), focused: true)
                ink.glyph(at: CGPoint(x: 50, y: 8))
                ink.panel(
                    CGRect(x: 22, y: 22, width: 86, height: 32),
                    rows: 3,
                    titled: true
                )
                .opacity(gestureStage(t, 0.6, 0.75))
                ink.pointer(
                    at: CGPoint(
                        x: gestureLerp(64, 38, gestureStage(t, 0, 0.35)),
                        y: 8
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
}
