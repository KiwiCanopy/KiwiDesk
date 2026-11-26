import Combine
import KiwiDeskCore
import SwiftUI

/// How far the picker's "puddle" exit has come (#3038 ▸ Ruling
/// 2026-11-23): a clear drop falls onto the card, the picker blurs,
/// and one wave opens a hole to the real desk until it leaves the
/// screen. The controller moves these values, each through a gated
/// animation; the views only draw them.
@MainActor
final class LookPickerReveal: ObservableObject {
    /// The drop has reached the card.
    @Published var dropLanded = false
    /// The drop has burst on the card.
    @Published var dropSplashed = false
    /// The drop is falling (shown) at all.
    @Published var dropShown = false
    /// The picker's own blur, in points.
    @Published var blur: CGFloat = 0
    /// The hole's radius, from the drop's point.
    @Published var holeRadius: CGFloat = 0
    /// The wave front shows while the hole grows.
    @Published var waveShown = false
    /// The whole overlay's opacity: Reduce Motion's cross-fade.
    @Published var opacity: Double = 1

    /// The drop's fall, the blur and the wave (#3038 ▸ Ruling).
    static let fall: TimeInterval = 0.35
    static let blurIn: TimeInterval = 0.18
    /// The drop's burst on landing.
    static let splash: TimeInterval = 0.12
    static let wave: TimeInterval = 0.6
    /// Reduce Motion's cross-fade.
    static let crossFade: TimeInterval = 0.2
    /// The picker's blur at its height, 8–10 pt.
    static let blurRadius: CGFloat = 9
    /// The wave front's band and rim.
    static let band: CGFloat = 70
    static let rim: CGFloat = 2
}

/// The overlay with a hole of `radius` at `centre`, even-odd filled:
/// what stays drawn of the picker while the wave opens the desk.
struct LookPickerHole: Shape {
    var centre: CGPoint
    var radius: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        guard radius > 0 else { return path }
        path.addEllipse(
            in: CGRect(
                x: centre.x - radius,
                y: centre.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        return path
    }
}

/// The wave front: a faint wash just inside the hole's edge and a
/// white rim on it — no material, which cannot blur as little as
/// the ruling's 5 pt (ui-designer consult 2026-11-26). Under Reduce
/// transparency, the rim alone.
struct LookPickerWave: View {
    let centre: CGPoint
    let radius: CGFloat
    let rimOnly: Bool

    var body: some View {
        ZStack {
            if !rimOnly {
                Circle().fill(
                    RadialGradient(
                        colors: [
                            SettingsTheme.plateInk.opacity(0),
                            SettingsTheme.plateInk.opacity(0.10),
                        ],
                        center: .center,
                        startRadius: max(0, radius - LookPickerReveal.band),
                        endRadius: radius
                    )
                )
            }
            Circle().strokeBorder(
                SettingsTheme.plateInk.opacity(0.85),
                lineWidth: LookPickerReveal.rim
            )
        }
        .frame(width: radius * 2, height: radius * 2)
        .position(centre)
        .allowsHitTesting(false)
    }
}

/// The small clear drop that falls onto the card.
struct LookPickerDrop: View {
    let landed: Bool
    let splashed: Bool
    /// Where it lands.
    let target: CGPoint

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        SettingsTheme.plateInk.opacity(0.95),
                        SettingsTheme.plateInk.opacity(0.25),
                        SettingsTheme.plateInk.opacity(0.4),
                    ],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 0,
                    endRadius: Self.size
                )
            )
            .overlay(
                Ellipse().strokeBorder(
                    SettingsTheme.plateInk.opacity(0.55),
                    lineWidth: 1
                )
            )
            .frame(width: Self.size, height: Self.size * 1.3)
            .scaleEffect(
                x: splashed ? 1.8 : 0.85,
                y: splashed ? 0.35 : 1.15
            )
            .opacity(splashed ? 0 : 1)
            .position(
                x: target.x,
                y: landed ? target.y : -Self.size * 2
            )
            .allowsHitTesting(false)
    }

    static let size: CGFloat = 34
}
