import AppKit
import KiwiDeskCore

/// Controller for shared `NSColorPanel` presented by `ColorSwatch`.
@MainActor
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var onChange: ((NSColor) -> Void)?
    private lazy var doneAccessory: NSView = makeDoneAccessory()
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
        panel.mode = .wheel
        panel.color = current
        panel.setTarget(self)
        panel.setAction(#selector(panelColorChanged(_:)))
        panel.makeKeyAndOrderFront(nil)
        return activeToken
    }

    /// Resigns panel if matching token still owns it.
    func resign(_ token: Int) {
        guard token == activeToken else { return }
        dismiss()
    }

    /// Dismisses shared NSColorPanel and clears accessories and callbacks.
    func dismiss() {
        onChange = nil
        let panel = NSColorPanel.shared
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
