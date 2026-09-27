import AppKit
import SwiftUI

/// Custom-styled slider with accessible keyboard and VoiceOver representation
/// (#68, #812).
struct SettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// Accessibility label for VoiceOver (#812).
    let label: String
    /// Spoken value readout with units for VoiceOver (#812).
    let spokenValue: String

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @FocusState private var focused: Bool
    /// True for the gesture's lifetime; resets on cancel too.
    @GestureState private var dragging = false

    private static let knobWidth: CGFloat = 30
    private static let knobHeight: CGFloat = 20
    private static let trackHeight: CGFloat = 6
    private static let height: CGFloat = 24
    /// Visual only — layout keeps the resting size (#1527).
    private static let dragScale: CGFloat = 1.25

    var body: some View {
        GeometryReader { geo in
            track(width: geo.size.width)
        }
        .frame(height: Self.height)
        .opacity(isEnabled ? 1 : 0.4)
        .focusable(isEnabled, interactions: .edit)
        .focused($focused)
        .onChange(of: focused) { _, now in
            // Refuse click-born focus on macOS 26; the predicate
            // is shared, the wiring is per-site by necessity
            // (`ClickBornFocus`).
            guard now,
                ClickBornFocus.isClickBorn(
                    focusMayBeADescendant: false
                )
            else { return }
            focused = false
        }
        .onKeyPress(.leftArrow) { nudge(-1) }
        .onKeyPress(.downArrow) { nudge(-1) }
        .onKeyPress(.rightArrow) { nudge(1) }
        .onKeyPress(.upArrow) { nudge(1) }
        .accessibilityRepresentation {
            Slider(value: $value, in: range, step: step)
        }
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue)
    }

    /// Increments or decrements value by step (code review 2026-08-24).
    private func nudge(_ direction: Double) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        let span = range.upperBound - range.lowerBound
        let increment = step > 0 ? step : span / 100
        value = snapped(value + direction * increment)
        return .handled
    }

    /// Snaps value to grid anchored at lowerBound.
    private func snapped(_ raw: Double) -> Double {
        let snapped =
            step > 0
            ? range.lowerBound
                + ((raw - range.lowerBound) / step).rounded()
                * step
            : raw
        return min(
            max(snapped, range.lowerBound),
            range.upperBound
        )
    }

    private var fill: AnyShapeStyle {
        isEnabled
            ? AnyShapeStyle(SettingsTheme.accent.gradient)
            : AnyShapeStyle(Color.primary.opacity(0.18))
    }

    private func track(width: CGFloat) -> some View {
        let center = knobCenter(in: width)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(height: Self.trackHeight)
            // To the knob's CENTRE, so a glass knob shows the
            // fill running under it (#1527).
            Capsule()
                .fill(fill)
                .frame(width: center, height: Self.trackHeight)
            knob
                .frame(
                    width: Self.knobWidth,
                    height: Self.knobHeight
                )
                .scaleEffect(dragging ? Self.dragScale : 1)
                .animation(
                    reduceMotion ? nil : .spring(duration: 0.25),
                    value: dragging
                )
                .offset(x: center - Self.knobWidth / 2)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragging) { _, state, _ in
                    state = isEnabled
                }
                .onChanged { drag in
                    guard isEnabled else { return }
                    set(at: drag.location.x, in: width)
                }
        )
    }

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

    private func set(at x: CGFloat, in width: CGFloat) {
        let usable = max(width - Self.knobWidth, 1)
        let t = min(max((x - Self.knobWidth / 2) / usable, 0), 1)
        let span = range.upperBound - range.lowerBound
        value = snapped(range.lowerBound + Double(t) * span)
    }

    /// White knob thumb, clear glass while dragged (#1527). The
    /// glass is Settings' own control finish, so it ignores the
    /// overlays' Liquid Glass switch; Reduce transparency and
    /// pre-26 keep the white knob through `glassChrome`.
    private var knob: some View {
        Color.clear
            .glassChrome(
                in: Capsule(),
                enabled: dragging,
                variant: .clear,
                fallback: AnyShapeStyle(.white)
            )
            .overlay(
                Capsule().strokeBorder(
                    Color.black.opacity(dragging ? 0 : 0.1),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: .black.opacity(dragging ? 0 : 0.25),
                radius: 2,
                y: 1
            )
    }
}
