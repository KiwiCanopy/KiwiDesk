import AppKit
import KiwiDeskCore

/// Drives the one shared `NSColorPanel` for every `ColorSwatch`.
/// The last swatch to open the panel owns it: `present`
/// retargets the panel and re-points the change callback,
/// mirroring how a native color well hands the panel between
/// wells. Split from `ColorField.swift` for the file ceiling.
@MainActor
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var onChange: ((NSColor) -> Void)?
    private lazy var doneAccessory: NSView = makeDoneAccessory()
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
        panel.accessoryView = doneAccessory
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
        let panel = NSColorPanel.shared
        // Detach our Done bar so it can't linger on the shared
        // panel for the process lifetime and bleed into any other
        // future `NSColorPanel.shared` user.
        panel.accessoryView = nil
        panel.orderOut(nil)
    }

    private func makeDoneAccessory() -> NSView {
        // The accessory is built before the panel is on screen, so
        // its content width isn't laid out yet; start at a sane
        // default and let `autoresizingMask` size it to the panel.
        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: 300, height: 42)
        )
        container.autoresizingMask = [.width]
        let button = NSButton(
            title: L("color_panel.done", "Done"),
            target: self,
            action: #selector(donePicking)
        )
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(
                equalTo: container.centerXAnchor
            ),
            button.centerYAnchor.constraint(
                equalTo: container.centerYAnchor
            ),
            button.leadingAnchor.constraint(
                greaterThanOrEqualTo: container.leadingAnchor,
                constant: 12
            ),
            button.trailingAnchor.constraint(
                lessThanOrEqualTo: container.trailingAnchor,
                constant: -12
            ),
        ])
        return container
    }

    @objc private func donePicking() {
        dismiss()
    }

    @objc private func panelColorChanged(
        _ sender: NSColorPanel
    ) {
        onChange?(sender.color)
    }
}
