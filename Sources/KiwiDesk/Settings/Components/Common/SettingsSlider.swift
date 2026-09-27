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
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency
    @FocusState private var focused: Bool
    /// The pointer's unsnapped track fraction while dragging; the
    /// knob follows it and settles on the snapped value when it
    /// resets, which it does on cancel too (#1527).
    @GestureState private var dragFraction: CGFloat?

    private var dragging: Bool { dragFraction != nil }

    private static let knobWidth: CGFloat = 28
    private static let knobHeight: CGFloat = 18
    private static let trackHeight: CGFloat = 10
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
                .offset(x: center - Self.knobWidth / 2)
        }
        // Press and release only: the drag itself tracks the
        // pointer unanimated, and the release settles the knob
        // onto the snapped value.
        .animation(
            reduceMotion ? nil : .spring(duration: 0.25),
            value: dragging
        )
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragFraction) { drag, state, _ in
                    guard isEnabled else { return }
                    state = trackFraction(at: drag.location.x, in: width)
                }
                .onChanged { drag in
                    guard isEnabled else { return }
                    let t = trackFraction(at: drag.location.x, in: width)
                    let span = range.upperBound - range.lowerBound
                    value = snapped(range.lowerBound + Double(t) * span)
                }
        )
    }

    private func knobCenter(in width: CGFloat) -> CGFloat {
        let usable = max(width - Self.knobWidth, 1)
        let t = min(max(dragFraction ?? fraction, 0), 1)
        return Self.knobWidth / 2 + usable * t
    }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat(
            (value - range.lowerBound) / span
        )
    }

    private func trackFraction(
        at x: CGFloat,
        in width: CGFloat
    ) -> CGFloat {
        let usable = max(width - Self.knobWidth, 1)
        return min(max((x - Self.knobWidth / 2) / usable, 0), 1)
    }

    /// True while the knob draws as glass rather than its white
    /// fallback — the branch `glassChrome` takes (#1374).
    private var knobIsGlass: Bool {
        dragging && !reduceTransparency && GlassChromeVariant.drawable
    }

    /// White knob thumb, fully clear glass while dragged (#1527).
    /// The glass is Settings' own control finish, so it ignores
    /// the overlays' Liquid Glass switch. The rim and shadow are
    /// the white knob's only edge and stand down only where the
    /// glass draws, since both read as frost through it.
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
                    Color.black.opacity(knobIsGlass ? 0 : 0.1),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: .black.opacity(knobIsGlass ? 0 : 0.25),
                radius: 2,
                y: 1
            )
    }
}
