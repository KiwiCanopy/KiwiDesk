import SwiftUI

/// The slider counterpart to `SegmentedPicker` (#68): the
/// same capsule track, a native-style white thumb overhanging
/// the track slightly, and an accent fill up to the knob so
/// the value reads at a glance. Values
/// snap to `step`. Accessibility is delegated to a native
/// `Slider` representation, so VoiceOver and keyboard
/// adjustment behave exactly like the control it replaces.
struct SettingsSlider: View {
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
            Slider(value: $value, in: range, step: step)
        }
    }

    /// Disabled sliders gray the fill itself — the dimming
    /// `.opacity` alone left the accent showing through the
    /// translucent white knob, which read as a blue knob.
    private var fill: AnyShapeStyle {
        isEnabled
            ? AnyShapeStyle(SettingsTheme.accent.gradient)
            : AnyShapeStyle(Color.primary.opacity(0.18))
    }

    private func track(width: CGFloat) -> some View {
        let center = knobCenter(in: width)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.08))
            Capsule()
                .fill(fill)
                .frame(width: center + Self.knobWidth / 2)
            // The knob overhangs the track by 2 pt per edge
            // (native sliders oversize the thumb); nothing
            // clips it — the row's padding absorbs the
            // overflow.
            knob
                .frame(
                    width: Self.knobWidth,
                    height: Self.height + 4
                )
                .offset(x: center - Self.knobWidth / 2)
        }
        .overlay(
            Capsule().strokeBorder(
                Color.primary.opacity(0.08),
                lineWidth: 0.5
            )
        )
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
    /// the pill never leaves the track — the fraction clamps
    /// so an out-of-range stored value (hand-edited config)
    /// renders at the nearest end like a native slider.
    private func knobCenter(in width: CGFloat) -> CGFloat {
        let usable = max(width - Self.knobWidth, 1)
        let t = min(max(fraction, 0), 1)
        return Self.knobWidth / 2 + usable * t
    }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat(
            (value - range.lowerBound) / span
        )
    }

    /// Snapping anchors at `lowerBound` (not zero) so ranges
    /// like `0.1...0.9` land on their own grid; a non-positive
    /// step means no snapping.
    private func set(at x: CGFloat, in width: CGFloat) {
        let usable = max(width - Self.knobWidth, 1)
        let t = min(max((x - Self.knobWidth / 2) / usable, 0), 1)
        let span = range.upperBound - range.lowerBound
        let raw = range.lowerBound + Double(t) * span
        let snapped =
            step > 0
            ? range.lowerBound
                + ((raw - range.lowerBound) / step).rounded()
                * step
            : raw
        value = min(
            max(snapped, range.lowerBound),
            range.upperBound
        )
    }

    /// The native white thumb, on every macOS and in BOTH
    /// appearances. A clear Liquid Glass knob was tried and
    /// dropped: it refracted the accent fill sliding beneath it,
    /// tinting the knob blue.
    ///
    /// Deliberately NOT `SettingsTheme.onAccentKnob`: that token
    /// flips near-black on the dark appearance, which suits a
    /// knob on a large accent field and not a thumb whose whole
    /// job is to be the brightest thing on a 4 pt track.
    private var knob: some View {
        Capsule()
            .fill(.white)
            .overlay(
                Capsule().strokeBorder(
                    Color.black.opacity(0.1),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: .black.opacity(0.25),
                radius: 2,
                y: 1
            )
    }
}
