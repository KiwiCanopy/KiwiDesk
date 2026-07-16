import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Appearance ▸ Focus border (#278). Sits below
/// Gaps and Drag & Drop. Order per the settled design: enable
/// toggle → live two-window preview → focused color → unfocused
/// toggle + color → width → corner style (preview leads editor,
/// AGENTS §2.7). Colors use the shared hex swatch — the same
/// control and format as the App Bar and drag colors.
struct FocusBorderEditor: View {
    @ObservedObject var model: SettingsModel

    private var style: Binding<BorderStyle> {
        $model.config.settings.borderStyle
    }

    var body: some View {
        SettingsSection(
            L("border.title", "Focus border"),
            caption: L(
                "border.caption",
                "Outlines the focused window so it stands out "
                    + "in a gapped layout."
            )
        ) {
            Toggle(
                L("border.enabled", "Show focus border"),
                isOn: style.enabled
            )
            FocusBorderPreview(style: style.wrappedValue)
            controls.modifier(
                GreyOut(active: !style.wrappedValue.enabled)
            )
        }
    }

    @ViewBuilder private var controls: some View {
        HexColorField(
            label: L("border.focused_color", "Color"),
            a11yLabel: L(
                "border.focused_color.a11y",
                "Focused window border color"
            ),
            hex: style.focusedColor
        )
        Divider()
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                L(
                    "border.unfocused_enabled",
                    "Show border on unfocused windows"
                ),
                isOn: style.unfocusedEnabled
            )
            HexColorField(
                label: L("border.unfocused_color", "Color"),
                a11yLabel: L(
                    "border.unfocused_color.a11y",
                    "Unfocused window border color"
                ),
                hex: style.unfocusedColor
            )
            .modifier(
                GreyOut(
                    active: !style.wrappedValue.unfocusedEnabled
                )
            )
        }
        Divider()
        PtSlider(
            label: L("border.width", "Width"),
            value: style.width,
            range: 1...20
        )
        SegmentedPicker(
            cornerLabel,
            selection: style.cornerStyle,
            options: [
                (L("border.corner.rounded", "Rounded"), .rounded),
                (L("border.corner.square", "Square"), .square),
            ]
        )
        Divider()
        VStack(alignment: .leading, spacing: 4) {
            Button(L("border.fit_gaps", "Fit gaps to border")) {
                fitGapsToBorder()
            }
            Text(
                L(
                    "border.fit_gaps.caption",
                    "Widens the layout gaps so borders never "
                        + "touch a neighbour — the inner gap "
                        + "doubles when unfocused borders are on."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var cornerLabel: String {
        L("border.corner_style", "Corners")
    }

    /// Writes the same `gapsGlobal` the Gaps sliders do, using the
    /// core's shared `BorderStyle.fittingGaps()` so the button and
    /// the `border.fit_gaps` command can't drift.
    private func fitGapsToBorder() {
        model.config.settings.gapsGlobal =
            model.config.settings.borderStyle.fittingGaps()
    }
}

/// Two mock windows on a neutral desktop: the focused one always
/// ringed, the other ringed only when unfocused borders are on.
/// Reflects width and corner style live so the editor's controls
/// preview before they hit real windows.
private struct FocusBorderPreview: View {
    let style: BorderStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            HStack(spacing: 16) {
                window(color: style.focusedColor, ringed: true)
                window(
                    color: style.unfocusedColor,
                    ringed: style.unfocusedEnabled
                )
            }
            .padding(14)
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity)
        .opacity(style.enabled ? 1 : 0.4)
    }

    private func window(
        color: String,
        ringed: Bool
    ) -> some View {
        // Remap the 1–20 pt width onto the preview's smaller span
        // so a thick border reads without swamping the mock.
        let width = scale(
            style.clampedWidth,
            from: 1...20,
            to: 1...7
        )
        let radius: CGFloat =
            style.cornerStyle == .square ? 0 : 12
        return RoundedRectangle(cornerRadius: radius)
            .fill(Color.secondary.opacity(0.25))
            .overlay {
                if ringed {
                    // Pure outset (#303): the ring sits entirely
                    // outside the window — grow the stroke rect by
                    // half the width and centre the stroke, so it
                    // never paints over the mock window's content.
                    RoundedRectangle(cornerRadius: radius + width / 2)
                        .stroke(
                            Color(kiwiHex: color),
                            lineWidth: width
                        )
                        .padding(-width / 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = min(max((value - src.lowerBound) / span, 0), 1)
        return dst.lowerBound
            + t * (dst.upperBound - dst.lowerBound)
    }
}
