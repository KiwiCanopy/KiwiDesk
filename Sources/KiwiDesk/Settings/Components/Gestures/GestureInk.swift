import SwiftUI

/// The shapes every gesture picture is drawn from (#1726), in the
/// user's palette on the plate (`HomeCardPlate.palette`). A moved
/// or dropped-on thing is told apart by outline and weight, never
/// by hue alone.
struct GestureInk {
    let palette: SchematicPalette?

    var accent: Color { palette?.accent ?? SettingsTheme.accent }
    var ink: Color { palette?.ink ?? SettingsTheme.plateInk }

    /// A window at rest.
    func window(_ rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(ink.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(ink.opacity(0.35), lineWidth: 1)
            )
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// The thing being dragged: dashed, filled in the accent.
    func ghost(_ rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(accent.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(
                        accent,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                    )
            )
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// Where it lands, or the one that holds focus: a heavy ring.
    func target(_ rect: CGRect, radius: CGFloat = 3) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .strokeBorder(accent, lineWidth: 2.2)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// The KiwiShelf strip along the top (or at `y`).
    func shelf(y: CGFloat = 0) -> some View {
        Rectangle()
            .fill(ink.opacity(0.16))
            .frame(width: GesturePlate<EmptyView>.size.width, height: 16)
            .offset(y: y)
    }

    /// A Space or App Bar item on the shelf.
    func item(_ rect: CGRect, label: String? = nil) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(ink.opacity(0.45), lineWidth: 1)
            .overlay {
                if let label {
                    Text(label)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.8))
                }
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// The Space the screen is showing: its item outlined in the
    /// accent, never a fill.
    func activeItem(_ rect: CGRect, label: String) -> some View {
        item(rect, label: label)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(accent, lineWidth: 1.2)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY),
                alignment: .topLeading
            )
    }

    /// The pointer, its tip at `point`.
    func pointer(at point: CGPoint) -> some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ink)
            .offset(x: point.x - 2, y: point.y - 1)
    }

    /// An app glyph inside a Space item; `focused` takes the
    /// accent ring, the way the bar marks the focused app.
    func glyph(at point: CGPoint, focused: Bool = false) -> some View {
        Circle()
            .fill(ink.opacity(0.55))
            .overlay {
                if focused {
                    Circle().strokeBorder(accent, lineWidth: 1.5)
                }
            }
            .frame(width: 7, height: 7)
            .offset(x: point.x - 3.5, y: point.y - 3.5)
    }

    /// Short text on the shelf, such as a `+n` count.
    func label(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(ink.opacity(0.85))
            .offset(x: point.x, y: point.y)
    }

    /// A menu or tooltip panel with `rows` lines of placeholder
    /// text, the first one bolder when `titled`.
    func panel(
        _ rect: CGRect,
        rows: Int,
        titled: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(ink.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(ink.opacity(0.4), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<rows, id: \.self) { row in
                        Capsule()
                            .fill(
                                ink.opacity(
                                    titled && row == 0 ? 0.8 : 0.45
                                )
                            )
                            .frame(
                                width: rect.width
                                    * (row.isMultiple(of: 2) ? 0.7 : 0.55),
                                height: 3
                            )
                    }
                }
                .padding(6)
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// A click at `point`: a ring that swells and fades while the
    /// press lasts, then is gone — nothing at rest.
    func press(at point: CGPoint, _ t: CGFloat) -> some View {
        let pulse = gestureStage(t, 0.15, 0.4)
        return Circle()
            .strokeBorder(accent, lineWidth: 1.5)
            .frame(width: 8 + 10 * pulse, height: 8 + 10 * pulse)
            .opacity(pulse > 0 && pulse < 1 ? 1 - pulse : 0)
            .offset(x: point.x - 4 - 5 * pulse, y: point.y - 4 - 5 * pulse)
    }

    /// A small motion cue, e.g. a scroll direction.
    func cue(_ symbol: String, at point: CGPoint) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(accent)
            .offset(x: point.x, y: point.y)
    }
}

/// Linear blend, for positions along a gesture.
func gestureLerp(
    _ from: CGFloat,
    _ to: CGFloat,
    _ t: CGFloat
) -> CGFloat {
    from + (to - from) * t
}

/// The progress of one stage of a gesture, 0 before `start` and 1
/// after `end` — so a picture can play steps in order (the ring
/// moves, then the pointer jumps), which a straight blend cannot.
/// Pictures are `Animatable`, so this is read every frame.
func gestureStage(
    _ t: CGFloat,
    _ start: CGFloat,
    _ end: CGFloat
) -> CGFloat {
    min(max((t - start) / (end - start), 0), 1)
}

/// An eased 0 → 1, for a stage of a `.story` picture to move
/// smoothly within its own window.
func gestureEase(_ x: CGFloat) -> CGFloat {
    x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
}
