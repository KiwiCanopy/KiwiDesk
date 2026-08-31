import AppKit
import KiwiDeskCore

/// Controller for the one shared `NSColorPanel`: the last swatch to
/// `present` owns it, like native color wells handing the panel over.
@MainActor
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var onChange: ((NSColor) -> Void)?
    private lazy var doneAccessory: NSView = makeDoneAccessory()
    /// Bumped per `present`; a swatch resigns the panel only while
    /// it still owns it.
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

    /// Unconditional teardown so the panel can't write into a
    /// reloaded config. `activeToken` deliberately NOT reset:
    /// `present` always advances it, so stale `resign` still no-ops.
    func dismiss() {
        onChange = nil
        let panel = NSColorPanel.shared
        // Detach our Done bar — the shared panel outlives us and
        // would show it to any future NSColorPanel user.
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
