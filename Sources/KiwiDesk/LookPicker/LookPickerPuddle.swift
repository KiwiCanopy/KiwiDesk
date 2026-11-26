import Combine
import KiwiDeskCore
import SwiftUI

/// How far the picker's "puddle" exit has come (#3038 ▸ Ruling
/// 2026-11-23, amended 2026-11-26): a clear drop falls onto the card,
/// lands, sinks in with a ripple, and only then the picker blurs and
/// one wave opens a hole to the real desk. The controller moves these
/// values, each through a gated animation; the views only draw them.
@MainActor
final class LookPickerReveal: ObservableObject {
    /// Where the drop is in its fall.
    enum DropStage {
        case hidden, above, landed, squashed, sunk
    }

    @Published var drop: DropStage = .hidden
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

/// The small clear drop: it falls onto the card, squashes as it
/// lands, then sinks in under a ripple.
struct LookPickerDrop: View {
    let stage: LookPickerReveal.DropStage
    /// Where it lands.
    let target: CGPoint

    var body: some View {
        ZStack {
            Ellipse()
                .strokeBorder(
                    SettingsTheme.plateInk.opacity(stage == .sunk ? 0 : 0.8),
                    lineWidth: 1.5
                )
                .frame(
                    width: stage == .sunk ? Self.ripple * 2 : 0,
                    height: stage == .sunk ? Self.ripple * 0.8 : 0
                )
                .position(target)
            drop
                .scaleEffect(
                    x: scale.x,
                    y: scale.y,
                    anchor: .bottom
                )
                .opacity(stage == .above || stage == .sunk ? 0 : 1)
                .position(
                    x: target.x,
                    y: stage == .above
                        ? target.y - LookPickerReveal.dropHeight : target.y
                )
        }
        .allowsHitTesting(false)
    }

    private var drop: some View {
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
    }

    private var scale: (x: CGFloat, y: CGFloat) {
        switch stage {
        case .hidden, .above, .landed: (0.85, 1.15)
        case .squashed: (1.3, 0.7)
        case .sunk: (0.2, 0.1)
        }
    }

    static let size: CGFloat = 34
    /// How far the sink's ripple spreads.
    static let ripple: CGFloat = 46
}
