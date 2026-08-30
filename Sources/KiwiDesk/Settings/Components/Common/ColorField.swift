import AppKit
import KiwiDeskCore
import SwiftUI

/// Labeled color control with swatch button and hex text field (#68, #231).
struct HexColorField: View {
    let label: String
    /// Accessibility label override for VoiceOver disambiguation (#231).
    var a11yLabel: String?
    /// Label column width.
    var labelWidth: CGFloat = SettingsMetrics.colorLabelColumn
    /// Whether an empty hex represents an "Automatic" adaptive value (#429).
    var automatic: Bool = false
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)
            ColorSwatch(
                label: a11yLabel ?? label,
                automatic: automatic,
                hex: $hex
            )
        }
    }

    /// Formats `NSColor` to `#RRGGBB` or `#RRGGBBAA` hex string.
    static func hexString(from color: NSColor) -> String {
        let ns = color.usingColorSpace(.sRGB) ?? .black
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        let a = Int(round(ns.alphaComponent * 255))
        if a >= 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return String(
            format: "#%02X%02X%02X%02X",
            r,
            g,
            b,
            a
        )
    }
}

/// Swatch button and hex input field for color editing (#68, #429).
struct ColorSwatch: View {
    let label: String
    /// Empty hex represents "Automatic" adaptive color (#429).
    var automatic: Bool = false
    @Binding var hex: String
    @State private var draft: String
    @FocusState private var focused: Bool
    @State private var token = 0

    init(
        label: String,
        automatic: Bool = false,
        hex: Binding<String>
    ) {
        self.label = label
        self.automatic = automatic
        self._hex = hex
        self._draft = State(initialValue: hex.wrappedValue)
    }

    /// True while this well is showing its adaptive "Automatic"
    /// state — an empty hex on a well that allows it.
    private var isAutomatic: Bool {
        automatic && hex.isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            swatchButton
            TextField(placeholder, text: $draft)
                .labelsHidden()
                .frame(width: SettingsMetrics.colorHexColumn)
                .font(.system(.caption, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, now in
                    if !now { commit() }
                }
                .help(
                    L(
                        "color_field.hex.help",
                        "Type a #RRGGBB or #RRGGBBAA value"
                    )
                )
                .accessibilityLabel(
                    L(
                        "color_field.hex.a11y",
                        "%1$@ hex value",
                        label
                    )
                )
        }
        // Track panel picks / external edits into the field —
        // but never mid-edit, or a background write would
        // discard the user's partial entry.
        .onChange(of: hex) { _, now in
            if !focused { draft = now }
        }
        // Resign the shared panel when this swatch leaves the
        // hierarchy, so a lingering panel can't write into a
        // torn-down binding.
        .onDisappear { ColorPanelController.shared.resign(token) }
    }

    /// The color dot as a discrete pressable chip: its own
    /// neutral background + hairline border carry the "button"
    /// signifier, so the affordance never merges into a dark
    /// fill the way a bare filled shape did. On an `automatic`
    /// well with no color set it shows the adaptive split state
    /// instead of a color, and a right-click clears back to it.
    private var swatchButton: some View {
        Button(action: present) {
            dot
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().strokeBorder(
                        Color.primary.opacity(0.25),
                        lineWidth: 0.5
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            Color.primary.opacity(0.15),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .hoverHighlight(
            restOpacity: 0.06,
            hoverOpacity: 0.12,
            cornerRadius: 6,
            padding: 0
        )
        .automaticMenu(automatic: automatic, hex: $hex, draft: $draft)
        .help(swatchHelp)
        .accessibilityLabel(
            isAutomatic
                ? L(
                    "color_field.swatch.a11y_auto",
                    "%1$@ color, Automatic",
                    label
                )
                : L(
                    "color_field.swatch.a11y",
                    "%1$@ color",
                    label
                )
        )
        .accessibilityHint(
            L(
                "color_field.swatch.a11y_hint",
                "Opens the color picker"
            )
        )
    }

    /// The dot itself: a diagonal light/dark split when Automatic
    /// (the macOS "Auto appearance" idiom — the adaptivity reads
    /// as a shape, not an absent color), else the flat color.
    @ViewBuilder private var dot: some View {
        if isAutomatic {
            Circle().fill(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.5),
                        .init(color: .black, location: 0.5),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            Circle().fill(color)
        }
    }

    private var swatchHelp: String {
        isAutomatic
            ? L(
                "color_field.swatch.help_auto",
                "Automatic — follows light and dark"
            )
            : L(
                "color_field.swatch.help",
                "Edit the %1$@ color",
                hex
            )
    }

    /// The hex field's placeholder: the word "Automatic" on an
    /// adaptive well with no color (so a blank box never reads as
    /// "unset by accident"), else empty.
    private var placeholder: String {
        isAutomatic
            ? L("color_field.hex.automatic", "Automatic") : ""
    }

    /// Falls back to `.clear` (an empty dot) when the stored
    /// string is not parseable.
    private var color: Color {
        guard let rgba = DragVisual.parseHex(hex) else {
            return .clear
        }
        return Color(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }

    /// Parse draft and normalize hex; empty field commits Automatic (#429).
    private func commit() {
        if automatic,
            draft.trimmingCharacters(in: .whitespaces).isEmpty
        {
            hex = ""
            draft = ""
            return
        }
        if let rgba = DragVisual.parseHex(draft) {
            let ns = NSColor(
                srgbRed: CGFloat(rgba.red),
                green: CGFloat(rgba.green),
                blue: CGFloat(rgba.blue),
                alpha: CGFloat(rgba.alpha)
            )
            hex = HexColorField.hexString(from: ns)
        }
        draft = hex
    }

    private func present() {
        // Seed opaque color when automatic to prevent 0-alpha picker (#429).
        let seed = isAutomatic ? NSColor.labelColor : NSColor(color)
        token = ColorPanelController.shared.present(
            current: seed
        ) { hex = HexColorField.hexString(from: $0) }
    }
}
