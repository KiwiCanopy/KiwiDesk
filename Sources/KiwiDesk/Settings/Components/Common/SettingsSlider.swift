import AppKit
import SwiftUI

/// The slider counterpart to `SegmentedPicker` (#68): the
/// same capsule track, a native-style white thumb overhanging
/// the track slightly, and an accent fill up to the knob so
/// the value reads at a glance. Values
/// snap to `step`. Accessibility is delegated to a native
/// `Slider` representation, so VoiceOver and keyboard
/// adjustment behave exactly like the control it replaces.
///
/// The representation is NAMED and VALUED here, by two
/// required arguments, because a bare `Slider` announces a
/// percentage of its range and nothing else: every row in this
/// tree draws its label and its readout as SIBLINGS of the
/// slider (`SettingsRowShape`), and a sibling `Text` names
/// nothing (gui.md ▸ the keyboard path). Nineteen rows shipped
/// "six percent" for "Outer gap, 6 pt" that way (#812). The
/// arguments have no defaults on purpose — the compiler is the
/// guard, and a site that cannot name its slider has found a
/// row with no label.
struct SettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// What VoiceOver calls the control — the row's label.
    let label: String
    /// What VoiceOver reads as its value — the row's readout,
    /// unit included ("6 pt", "29%", "1.5 s"), never the
    /// native percentage.
    let spokenValue: String

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool

    private static let knobWidth: CGFloat = 26
    private static let height: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            track(width: geo.size.width)
        }
        .frame(height: Self.height)
        .opacity(isEnabled ? 1 : 0.4)
        // A custom-drawn view holds no keyboard focus of its own,
        // so Tab skipped every slider in the tree and a keyboard
        // user could not change a gap at all (owner, #812 device
        // session 1). The AX representation below does not grant
        // it either — VoiceOver's cursor is its own — so the view
        // re-earns the two things a native `Slider` gave free:
        // a Tab stop with the platform's ring, and arrow keys
        // stepping by `step`. `.edit` interactions only: bare
        // `.focusable` also took focus on CLICK, which no
        // native macOS control does outside text fields
        // (owner, #812 session 3) — Tab reaches it, the
        // pointer never moves the ring.
        .focusable(isEnabled, interactions: .edit)
        .focused($focused)
        // `.edit` should already refuse click-focus and on
        // macOS 26 does not (device, 2026-08-24): focus that
        // arrives while a mouse button is down is click-born
        // and is handed back, so only Tab moves the ring here.
        // The live `NSEvent` read has precedent
        // (`MouseFollowsFocusTests`' seam) and is the one
        // deterministic discriminator between the two roads.
        .onChange(of: focused) { _, now in
            guard now, NSEvent.pressedMouseButtons != 0 else {
                return
            }
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

    /// One keyboard step in `direction`; a non-positive `step`
    /// (no snapping) moves by a hundredth of the range.
    private func nudge(_ direction: Double) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        let span = range.upperBound - range.lowerBound
        let increment = step > 0 ? step : span / 100
        // Through the same snap the drag applies: an off-grid
        // stored value (hand-edited config) must land on the
        // grid on the first arrow press, not stay offset
        // forever (code review, 2026-08-24).
        value = snapped(value + direction * increment)
        return .handled
    }

    /// The lowerBound-anchored grid both input paths share.
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
        value = snapped(range.lowerBound + Double(t) * span)
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
