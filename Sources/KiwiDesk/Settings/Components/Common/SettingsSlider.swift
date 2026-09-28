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
    /// A signed value's origin: the fill runs from it to the knob,
    /// either way, and a tick marks it. Nil fills from the leading
    /// edge.
    var origin: Double? = nil
    /// A darker/lighter scale (the sheen): moon and sun at the
    /// ends, a ramp on the track, and the origin notch showing
    /// above and below the knob while the value rests on it.
    var lightness = false

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

    private static let knobWidth: CGFloat = 24
    private static let knobHeight: CGFloat = 16
    private static let trackHeight: CGFloat = 12
    private static let height: CGFloat = 24
    /// Visual only — layout keeps the resting size (#1527).
    private static let dragScale: CGFloat = 1.25

    var body: some View {
        HStack(spacing: Self.endSpacing) {
            if lightness { endGlyph("moon.fill") }
            GeometryReader { geo in
                track(width: geo.size.width)
            }
            if lightness { endGlyph("sun.max.fill") }
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
        let span = Self.fillSpan(
            knob: center,
            origin: origin.map { restingCenter(at: $0, in: width) }
        )
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .overlay { if lightness && isEnabled { lightnessRamp } }
                .frame(height: Self.trackHeight)
            // To the knob's CENTRE, so a glass knob shows the
            // fill running under it (#1527) — from the origin
            // where the value is signed, following the drag.
            Capsule()
                .fill(fill)
                .frame(width: span.width, height: Self.trackHeight)
                .offset(x: span.x)
            if let origin {
                Rectangle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(
                        width: Self.notchWidth,
                        height: Self.trackHeight + 4
                    )
                    .offset(
                        x: restingCenter(at: origin, in: width)
                            - Self.notchWidth / 2
                    )
            }
            knob
                .overlay {
                    if lightness && restsOnOrigin && !dragging {
                        originMarks(knobHeight: Self.knobHeight)
                    }
                }
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

    private var fraction: CGFloat { fraction(of: value) }

    private func fraction(of at: Double) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((at - range.lowerBound) / span)
    }

    /// Where the knob's centre rests for `at`, drag aside.
    private func restingCenter(at: Double, in width: CGFloat) -> CGFloat {
        let usable = max(width - Self.knobWidth, 1)
        let t = min(max(fraction(of: at), 0), 1)
        return Self.knobWidth / 2 + usable * t
    }

    /// The accent fill's leading x and width: from the leading edge
    /// to the knob's centre, or — with an origin — between the
    /// origin's centre and the knob's, whichever way the value lies.
    static func fillSpan(
        knob: CGFloat,
        origin: CGFloat?
    ) -> (x: CGFloat, width: CGFloat) {
        guard let origin else { return (0, knob) }
        return (min(origin, knob), abs(knob - origin))
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

    /// Within half a step of `origin`: the grid may miss 0 by an ulp.
    var restsOnOrigin: Bool {
        guard let origin else { return false }
        return abs(value - origin) < max(step, 1e-9) / 2
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
