import AppKit
import KiwiDeskCore
import SwiftUI

/// A labeled color control (#68 §3.14): a lightweight swatch
/// that opens the shared system color panel on click, instead
/// of a per-row `NSColorWell`. The Appearance tab mounts ~14 of
/// these; a color well each is expensive to instantiate in
/// bulk (a visible open lag), while a swatch is a cheap filled
/// shape and there is only ever one system panel. Beside the
/// swatch an inline hex field types/pastes an exact value: the
/// system panel's hex field is 6-digit RGB only, so it cannot
/// express the alpha our `#RRGGBBAA` format carries — the
/// inline field is the only path to an exact translucent color.
/// "Hex" in the name is also the STORAGE contract: the binding
/// is the `#RRGGBBAA` string the config persists. One component
/// everywhere a color appears (App Bar, overrides, drag
/// visuals).
struct HexColorField: View {
    let label: String
    /// The screen label may be shortened to its in-group form
    /// ("Color" under a Border/Fill group, #231); VoiceOver
    /// still needs the disambiguated name, so `a11yLabel`
    /// overrides what `ColorSwatch` announces. Defaults to the
    /// visible `label` when they're the same.
    var a11yLabel: String?
    /// Label-column width — narrowed in the Drag editor's
    /// half-width columns (#231); the App Bar color grid keeps
    /// the default `colorLabelColumn`.
    var labelWidth: CGFloat = SettingsMetrics.colorLabelColumn
    /// Whether an EMPTY hex is a valid "Automatic" value (#429):
    /// the swatch then shows an adaptive split state and an empty
    /// entry commits instead of reverting. Off for the ~14 wells
    /// whose color has a concrete default and no adaptive concept.
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

    /// Formats an `NSColor` back into the stored hex string:
    /// `#RRGGBB`, or `#RRGGBBAA` when translucent.
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

/// The color control: two adjacent native affordances, not one
/// filled shape. A bordered swatch *button* (the color dot in a
/// pressable chip) opens the shared system panel for visual
/// picking; a `.roundedBorder` hex *field* beside it types or
/// pastes an exact value — the only path to an `#RRGGBBAA`
/// alpha the system panel's 6-digit hex field can't express.
/// The two pieces are shaped like the two different controls
/// they are (button vs. text field, with a gap between), so the
/// split reads as "two controls" rather than one ambiguous hit
/// region. Both write the same `hex`, so a panel pick repaints
/// the dot and updates the field, and a typed value repaints
/// the dot — they stay in sync for free.
struct ColorSwatch: View {
    let label: String
    /// Empty hex = "Automatic" (adaptive), not a parse failure —
    /// see `HexColorField.automatic`.
    var automatic: Bool = false
    @Binding var hex: String
    /// The field edits a string proxy so intermediate typing
    /// never clobbers `hex`; it commits (parse + normalize) on
    /// Return or focus loss, matching `StepperRow`'s discipline.
    @State private var draft: String
    @FocusState private var focused: Bool
    /// The panel-ownership token from the last `present`, so
    /// this swatch can resign the shared panel when it goes
    /// away (tab switch, App Bar disclosure collapse) without
    /// clobbering a later swatch that took the panel.
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

    /// Parse the draft; on success normalize the GUI's own
    /// write via `hexString` (uppercase, alpha dropped when
    /// opaque) — the Lua/CLI command paths store raw hex, so
    /// the stored form is not canonical, only the parser is
    /// shared. On failure silently revert to the last-good
    /// value.
    private func commit() {
        // On an adaptive well, an emptied field is a valid commit
        // to "Automatic" — not a parse failure to revert (#429).
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
        // Seed an OPAQUE color when Automatic: the empty well's
        // `color` is `.clear` (alpha 0), which would open the panel
        // with the opacity slider at zero — a hue picked without
        // touching alpha would commit an invisible mark (#429).
        let seed = isAutomatic ? NSColor.labelColor : NSColor(color)
        token = ColorPanelController.shared.present(
            current: seed
        ) { hex = HexColorField.hexString(from: $0) }
    }
}

extension View {
    /// The right-click clear path for an adaptive well (#429): one
    /// "Automatic" item, checked while the well already is, that
    /// resets the color to the empty sentinel. A no-op wrapper on a
    /// well that has no Automatic concept. This is the discoverable
    /// way back — the swatch click opens the picker (a concrete
    /// pick), and typing an empty value is the other path.
    @ViewBuilder
    fileprivate func automaticMenu(
        automatic: Bool,
        hex: Binding<String>,
        draft: Binding<String>
    ) -> some View {
        if automatic {
            contextMenu {
                Button {
                    hex.wrappedValue = ""
                    draft.wrappedValue = ""
                } label: {
                    if hex.wrappedValue.isEmpty {
                        Label(
                            L("color_field.automatic", "Automatic"),
                            systemImage: "checkmark"
                        )
                    } else {
                        Text(
                            L("color_field.automatic", "Automatic")
                        )
                    }
                }
            }
        } else {
            self
        }
    }
}
