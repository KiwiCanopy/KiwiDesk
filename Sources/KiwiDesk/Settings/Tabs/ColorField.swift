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
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(
                    width: SettingsMetrics.colorLabelColumn,
                    alignment: .leading
                )
            ColorSwatch(label: label, hex: $hex)
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
    @Binding var hex: String
    /// The field edits a string proxy so intermediate typing
    /// never clobbers `hex`; it commits (parse + normalize) on
    /// Return or focus loss, matching `StepperRow`'s discipline.
    @State private var draft: String
    @State private var hovering = false
    @FocusState private var focused: Bool
    /// The panel-ownership token from the last `present`, so
    /// this swatch can resign the shared panel when it goes
    /// away (tab switch, App Bar disclosure collapse) without
    /// clobbering a later swatch that took the panel.
    @State private var token = 0

    init(label: String, hex: Binding<String>) {
        self.label = label
        self._hex = hex
        self._draft = State(initialValue: hex.wrappedValue)
    }

    var body: some View {
        HStack(spacing: 6) {
            swatchButton
            TextField("", text: $draft)
                .labelsHidden()
                .frame(width: SettingsMetrics.colorHexColumn)
                .font(.system(.caption, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, now in
                    if !now { commit() }
                }
                .help("Type a #RRGGBB or #RRGGBBAA value")
                .accessibilityLabel("\(label) hex value")
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
    /// fill the way a bare filled shape did.
    private var swatchButton: some View {
        Button(action: present) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().strokeBorder(
                        Color.primary.opacity(0.25),
                        lineWidth: 0.5
                    )
                )
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            Color.primary.opacity(
                                hovering ? 0.12 : 0.06
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            Color.primary.opacity(0.15),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { hovering = $0 }
        .help("Edit the \(hex) color")
        .accessibilityLabel("\(label) color")
        .accessibilityHint("Opens the color picker")
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
        token = ColorPanelController.shared.present(
            current: NSColor(color)
        ) { hex = HexColorField.hexString(from: $0) }
    }
}

/// Drives the one shared `NSColorPanel` for every `ColorSwatch`.
/// The last swatch to open the panel owns it: `present`
/// retargets the panel and re-points the change callback,
/// mirroring how a native color well hands the panel between
/// wells.
@MainActor
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var onChange: ((NSColor) -> Void)?
    /// Bumped per `present`; identifies the current owner so a
    /// swatch only resigns the panel while it still owns it.
    private var activeToken = 0

    @discardableResult
    func present(
        current: NSColor,
        onChange: @escaping (NSColor) -> Void
    ) -> Int {
        activeToken += 1
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        // Open on the colour wheel (preferred over the sliders
        // pane, even though hex entry lives there).
        panel.mode = .wheel
        panel.color = current
        panel.setTarget(self)
        panel.setAction(#selector(panelColorChanged(_:)))
        panel.makeKeyAndOrderFront(nil)
        return activeToken
    }

    /// Detach when the owning swatch disappears — only if it is
    /// still the owner (a later swatch may have taken over).
    func resign(_ token: Int) {
        guard token == activeToken else { return }
        dismiss()
    }

    /// Unconditional teardown, e.g. on window close: stop
    /// routing and put the panel away so it can't write into a
    /// reloaded config after the window is gone. `activeToken`
    /// is intentionally NOT reset — `present` always advances
    /// it, so a later `resign(oldToken)` still no-ops; resetting
    /// to 0 would collide with a never-clicked swatch's initial
    /// token.
    func dismiss() {
        onChange = nil
        NSColorPanel.shared.orderOut(nil)
    }

    @objc private func panelColorChanged(
        _ sender: NSColorPanel
    ) {
        onChange?(sender.color)
    }
}
