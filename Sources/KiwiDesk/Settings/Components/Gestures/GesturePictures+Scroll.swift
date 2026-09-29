import KiwiDeskCore
import SwiftUI

/// The scroll-gesture picture (#1656, variant C): the held keys,
/// "+", a trackpad whose two fingertips slide "/" a mouse whose
/// wheel rolls, under a row whose focus steps one window and pans.
/// Same contract as `GesturePictures`: `t` runs 0 → 1, and the rest
/// frame at 1 matches the first.
extension GesturePicture {
    struct ScrollStep: View, Animatable {
        var t: CGFloat
        /// The chord in effect; none draws the inputs alone.
        let chord: ScrollChord
        nonisolated var animatableData: CGFloat {
            get { t }
            set { t = newValue }
        }
        @Environment(\.schematicPalette) private var palette

        var body: some View {
            let ink = GestureInk(palette: palette)
            let swipe = gestureEase(gestureStage(t, 0.1, 0.4))
            let focus = gestureStage(t, 0.4, 0.5)
            let pan = -50 * gestureEase(gestureStage(t, 0.5, 0.8))
            let keys = ScrollChordGlyphs.symbols(chord)
            let pad = 6 + 13 * CGFloat(keys.count) + (keys.isEmpty ? 0 : 8)
            ZStack(alignment: .topLeading) {
                ForEach(-1..<4, id: \.self) { index in
                    ink.window(
                        CGRect(
                            x: 8 + 50 * CGFloat(index) + pan,
                            y: 6,
                            width: 44,
                            height: 44
                        )
                    )
                }
                ink.target(CGRect(x: 58 + pan, y: 6, width: 44, height: 44))
                    .opacity(1 - focus)
                ink.target(CGRect(x: 108 + pan, y: 6, width: 44, height: 44))
                    .opacity(focus)
                ForEach(Array(keys.enumerated()), id: \.offset) { at, key in
                    ink.keycap(
                        key,
                        at: CGPoint(x: 6 + 13 * CGFloat(at), y: 57),
                        held: true
                    )
                }
                if !keys.isEmpty {
                    ink.legendMark("+", at: CGPoint(x: pad - 7, y: 56))
                }
                ink.trackpad(at: CGPoint(x: pad, y: 55), swipe)
                ink.legendMark("/", at: CGPoint(x: pad + 25, y: 57))
                ink.mouse(at: CGPoint(x: pad + 31, y: 54), swipe)
            }
        }
    }
}

/// A scroll chord as the keycaps draw it, in the ⌃⌥⇧⌘ order.
enum ScrollChordGlyphs {
    static func symbols(_ chord: ScrollChord) -> [String] {
        var result: [String] = []
        if chord.contains(.control) { result.append("⌃") }
        if chord.contains(.option) { result.append("⌥") }
        if chord.contains(.shift) { result.append("⇧") }
        if chord.contains(.command) { result.append("⌘") }
        return result
    }

    /// The whole chord as one run of glyphs.
    static func text(_ chord: ScrollChord) -> String {
        symbols(chord).joined()
    }
}

extension GestureInk {
    /// A modifier key; `held` takes the accent fill and a heavier
    /// outline, never the colour alone.
    func keycap(_ symbol: String, at point: CGPoint, held: Bool) -> some View {
        Text(symbol)
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(ink)
            .frame(minWidth: 11, minHeight: 11)
            .background(
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(held ? accent.opacity(0.22) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(
                        held ? accent : ink.opacity(0.45),
                        lineWidth: held ? 1.5 : 1
                    )
            )
            .offset(x: point.x, y: point.y)
    }

    /// A "+" or "/" between the legend's pieces.
    func legendMark(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(ink.opacity(0.7))
            .offset(x: point.x, y: point.y)
    }

    /// A small trackpad whose two fingertips slide left as
    /// `swipe` runs 0 → 1.
    func trackpad(at point: CGPoint, _ swipe: CGFloat) -> some View {
        let slide = gestureLerp(3, -4, swipe)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ink.opacity(0.06))
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(ink.opacity(0.55), lineWidth: 1)
            ForEach([6, 12], id: \.self) { x in
                Circle()
                    .fill(accent)
                    .frame(width: 4, height: 4)
                    .offset(x: CGFloat(x) + slide, y: 4.5)
            }
        }
        .frame(width: 22, height: 14, alignment: .topLeading)
        .offset(x: point.x, y: point.y)
    }

    /// A small mouse whose wheel's ridges roll up as `swipe` runs
    /// 0 → 1.
    func mouse(at point: CGPoint, _ swipe: CGFloat) -> some View {
        let roll = -2.6 * swipe
        let wheel = CGRect(x: 4.9, y: 2.6, width: 2.2, height: 4.2)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5.5)
                .fill(ink.opacity(0.07))
            RoundedRectangle(cornerRadius: 5.5)
                .strokeBorder(ink.opacity(0.6), lineWidth: 0.9)
            Rectangle()
                .fill(ink.opacity(0.35))
                .frame(width: 0.7, height: 6.6)
                .offset(x: 5.65, y: 0.8)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(accent)
                ForEach(0..<5, id: \.self) { ridge in
                    Rectangle()
                        .fill(SettingsTheme.previewPlate.opacity(0.55))
                        .frame(width: wheel.width, height: 0.5)
                        .offset(y: 0.2 + 1.3 * CGFloat(ridge) + roll)
                }
            }
            .frame(width: wheel.width, height: wheel.height, alignment: .top)
            .clipShape(Capsule())
            .offset(x: wheel.minX, y: wheel.minY)
        }
        .frame(width: 12, height: 17, alignment: .topLeading)
        .offset(x: point.x, y: point.y)
    }
}
