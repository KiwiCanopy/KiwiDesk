import SwiftUI

/// The slider counterpart to `GlassSegmentedPicker` (#68): the
/// same capsule track, a Liquid Glass pill as the knob (the
/// bordered material capsule before macOS 26), and an accent
/// fill up to the knob so the value reads at a glance. Values
/// snap to `step`. Accessibility is delegated to a native
/// `Slider` representation, so VoiceOver and keyboard
/// adjustment behave exactly like the control it replaces.
struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1

    @Environment(\.isEnabled) private var isEnabled

    private static let knobWidth: CGFloat = 26
    private static let height: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            track(width: geo.size.width)
        }
        .frame(height: Self.height)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }

    private func track(width: CGFloat) -> some View {
        let center = knobCenter(in: width)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.06))
            Capsule()
                .fill(Color.accentColor.opacity(0.22))
                .frame(width: center + Self.knobWidth / 2)
            knob
                .frame(
                    width: Self.knobWidth,
                    height: Self.height - 4
                )
                .offset(x: center - Self.knobWidth / 2)
        }
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard isEnabled else { return }
                    set(at: drag.location.x, in: width)
                }
        )
    }

    /// The knob's center, from half a knob in on both ends so
    /// the pill never leaves the track.
    private func knobCenter(in width: CGFloat) -> CGFloat {
        let usable = max(width - Self.knobWidth, 1)
        return Self.knobWidth / 2 + usable * fraction
    }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat(
            (value - range.lowerBound) / span
        )
    }

    private func set(at x: CGFloat, in width: CGFloat) {
        let usable = max(width - Self.knobWidth, 1)
        let t = min(max((x - Self.knobWidth / 2) / usable, 0), 1)
        let span = range.upperBound - range.lowerBound
        let raw = range.lowerBound + Double(t) * span
        let snapped = (raw / step).rounded() * step
        value = min(
            max(snapped, range.lowerBound),
            range.upperBound
        )
    }

    /// A lone glass element with no text on it, so it needs no
    /// container and nothing can blur behind it.
    @ViewBuilder private var knob: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .regular.interactive(),
                    in: Capsule()
                )
        } else {
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule().strokeBorder(
                        Color.primary.opacity(0.12),
                        lineWidth: 0.5
                    )
                )
                .shadow(
                    color: .black.opacity(0.12),
                    radius: 2,
                    y: 1
                )
        }
    }
}
