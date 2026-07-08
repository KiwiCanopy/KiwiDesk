import AppKit
import KiwiDeskCore
import SwiftUI

/// A labeled color control (#68 §3.14): a lightweight swatch
/// that opens the shared system color panel on click, instead
/// of a per-row `NSColorWell`. The Appearance tab mounts ~14 of
/// these; a color well each is expensive to instantiate in
/// bulk (a visible open lag), while a swatch is a cheap filled
/// shape and there is only ever one system panel. The panel's
/// "RGB Sliders" mode carries the hex field, so no custom hex
/// UI is needed. "Hex" in the name is the STORAGE contract, not
/// the UI: the binding is the `#RRGGBBAA` string the config
/// persists. One component everywhere a color appears (App Bar,
/// overrides, drag visuals).
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
            ColorSwatch(hex: $hex)
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

/// The clickable color preview. Reads `hex` via
/// `DragVisual.parseHex` (handles `#RRGGBB` and `#RRGGBBAA`)
/// and writes back whatever the shared panel reports.
struct ColorSwatch: View {
    @Binding var hex: String
    @State private var hovering = false
    /// The panel-ownership token from the last `present`, so
    /// this swatch can resign the shared panel when it goes
    /// away (tab switch, App Bar disclosure collapse) without
    /// clobbering a later swatch that took the panel.
    @State private var token = 0

    var body: some View {
        Button(action: present) {
            Capsule()
                .fill(color)
                .frame(width: 44, height: 22)
                .overlay(
                    // Top bevel highlight — the raised-well
                    // look, so the swatch isn't a flat chip.
                    Capsule()
                        .inset(by: 1)
                        .strokeBorder(
                            .white.opacity(0.4),
                            lineWidth: 0.75
                        )
                )
                .overlay(
                    // Appearance-adaptive ring: white-ish in
                    // dark mode, dark in light — a defined
                    // border in both, unlike the faint
                    // separator that vanished on dark fills.
                    Capsule()
                        .strokeBorder(
                            Color.primary.opacity(0.35),
                            lineWidth: 1
                        )
                )
                // Persistent raised shadow (the "3D",
                // interactive vocabulary), amplified on hover.
                .scaleEffect(hovering ? 1.06 : 1)
                .shadow(
                    color: .black.opacity(0.35),
                    radius: hovering ? 4 : 2,
                    y: hovering ? 2 : 1
                )
                .animation(
                    .easeOut(duration: 0.12),
                    value: hovering
                )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { hovering = $0 }
        .help("Edit the \(hex) color")
        // Resign the shared panel when this swatch leaves the
        // hierarchy, so a lingering panel can't write into a
        // torn-down binding.
        .onDisappear { ColorPanelController.shared.resign(token) }
    }

    /// Falls back to `.clear` (a bordered empty swatch) when the
    /// stored string is not parseable.
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
