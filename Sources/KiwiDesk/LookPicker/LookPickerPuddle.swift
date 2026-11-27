import Combine
import KiwiDeskCore
import SwiftUI

/// How far the picker's "puddle" exit has come (#3038 ▸ Ruling
/// 2026-11-23, amended 2026-11-26): a clear drop falls onto the card,
/// lands, sinks in with a ripple, and only then the picker blurs and
/// one wave opens a hole to the real desk. It holds the wave's
/// values, which the controller moves through gated animations, and
/// the whole sequence's timings; `LookPickerDropView` plays the drop.
@MainActor
final class LookPickerReveal: ObservableObject {
    /// The picker's own blur, in points.
    @Published var blur: CGFloat = 0
    /// The hole's radius, from the drop's point.
    @Published var holeRadius: CGFloat = 0
    /// The wave front shows while the hole grows.
    @Published var waveShown = false
    /// The whole overlay's opacity: Reduce Motion's cross-fade.
    @Published var opacity: Double = 1

    /// The drop's fall from `dropHeight` above the card.
    static let fall: TimeInterval = 0.22
    /// The drop's fade-in at the top of its fall.
    static let dropFade: TimeInterval = 0.06
    /// How long the drop rests squashed before it sinks.
    static let squashHold: TimeInterval = 0.08
    /// The sink and its ripple.
    static let sink: TimeInterval = 0.24
    /// From the sink's start to the wave's, so the drop is gone first.
    static let waveLead: TimeInterval = 0.2
    static let blurIn: TimeInterval = 0.18
    static let wave: TimeInterval = 0.6
    /// Reduce Motion's cross-fade.
    static let crossFade: TimeInterval = 0.2
    /// The picker's blur at its height, 8–10 pt.
    static let blurRadius: CGFloat = 9
    /// How far above the card's centre the drop starts.
    static let dropHeight: CGFloat = 260
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

/// The wave front: a frosted band 70 pt wide, lifted a little, with
/// a white rim on its edge (owner, prototype 2026-11-26). The
/// material blurs the desk behind the panel more than the ruling's
/// 5 pt; no public API sets that radius. Under Reduce transparency,
/// the rim alone.
struct LookPickerWave: View {
    let centre: CGPoint
    let radius: CGFloat
    let rimOnly: Bool

    var body: some View {
        ZStack {
            if !rimOnly {
                Circle().fill(.ultraThinMaterial)
                    .overlay(
                        Circle().fill(
                            RadialGradient(
                                colors: [
                                    SettingsTheme.plateInk.opacity(0),
                                    SettingsTheme.plateInk.opacity(0.18),
                                ],
                                center: .center,
                                startRadius: max(
                                    0,
                                    radius - LookPickerReveal.band
                                ),
                                endRadius: radius
                            )
                        )
                    )
                    .mask(
                        Circle()
                            .strokeBorder(lineWidth: LookPickerReveal.band)
                            .blur(radius: 10)
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
