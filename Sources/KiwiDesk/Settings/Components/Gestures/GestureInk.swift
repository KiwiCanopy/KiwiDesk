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

    /// The pointer, its tip at `point`.
    func pointer(at point: CGPoint) -> some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ink)
            .offset(x: point.x - 2, y: point.y - 1)
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
