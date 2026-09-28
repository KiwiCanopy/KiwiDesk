import SwiftUI

/// The Space Bar glyph pictures (#1726 entries for #1528's click
/// targets and #1514's hover title). Same contract as
/// `GesturePicture`: `t` runs 0 → 1 and 1 is the key frame.
extension GesturePicture {
    /// Click an app glyph that carries a window count: its
    /// windows open as a menu (a one-window glyph just focuses).
    struct GlyphClick: View {
        let t: CGFloat
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
                ink.panel(
                    CGRect(x: 30, y: 20, width: 64, height: 34),
                    rows: 3
                )
                .opacity(t)
                ink.pointer(at: CGPoint(x: 38, y: gestureLerp(30, 8, t)))
            }
        }
    }

    /// Click `+n`: a menu of the windows the item did not draw.
    struct OverflowMenu: View {
        let t: CGFloat
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
                ink.panel(
                    CGRect(x: 40, y: 20, width: 70, height: 44),
                    rows: 4
                )
                .opacity(t)
                ink.pointer(at: CGPoint(x: 58, y: gestureLerp(30, 10, t)))
            }
        }
    }

    /// Point at an app glyph: its app and window titles show.
    struct GlyphHover: View {
        let t: CGFloat
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
                .opacity(t)
                ink.pointer(at: CGPoint(x: gestureLerp(60, 38, t), y: 8))
            }
        }
    }
}
