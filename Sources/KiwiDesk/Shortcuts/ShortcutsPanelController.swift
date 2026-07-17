import AppKit
import KiwiDeskCore
import SwiftUI

/// A floating panel that closes on Esc (`cancelOperation`) and,
/// via the controller's resign-key handler, on click-away.
final class ShortcutsPanel: NSPanel {
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}

/// Owns the read-only shortcuts reference panel (#326). Retained by
/// `AppDelegate` so it survives close/reopen. Every show reads the
/// live keybinding snapshot fresh and re-centers on the screen
/// under the pointer — the panel has no placement of its own to
/// remember (a summoned reference, not a window the user parks).
@MainActor
final class ShortcutsPanelController: NSObject, NSWindowDelegate {
    private let core: KiwiCore
    /// Opens Settings ▸ Shortcuts — the one bridge to editing.
    private let onEdit: () -> Void
    private var panel: ShortcutsPanel?

    init(core: KiwiCore, onEdit: @escaping () -> Void) {
        self.core = core
        self.onEdit = onEdit
        super.init()
    }

    func show() {
        let reference = buildReference()
        let root = ShortcutsPanelView(
            reference: reference,
            onEdit: { [weak self] in
                self?.close()
                self?.onEdit()
            }
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(
            rootView: root.environmentObject(
                LocalizationManager.shared
            )
        )
        resize(panel)
        center(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
    }

    // MARK: - Panel construction

    private func makePanel() -> ShortcutsPanel {
        let panel = ShortcutsPanel(
            contentRect: .zero,
            styleMask: [
                .borderless, .nonactivatingPanel,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary,
        ]
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }
        return panel
    }

    // MARK: - Sizing & placement

    /// Hug the content, capped at 70% of the active screen's
    /// height (hard ceiling 720pt) — past that the inner scroll
    /// view takes over. Width is fixed by the view (760pt).
    private func resize(_ panel: ShortcutsPanel) {
        guard let content = panel.contentView else { return }
        let fitting = content.fittingSize
        let screen =
            screenUnderPointer()?.visibleFrame.height
            ?? fitting.height
        let ceiling = min(screen * 0.7, 720)
        let height = min(fitting.height, ceiling)
        panel.setContentSize(
            NSSize(width: fitting.width, height: height)
        )
    }

    private func center(_ panel: ShortcutsPanel) {
        guard let screen = screenUnderPointer() else {
            panel.center()
            return
        }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    private func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouse, $0.frame, false)
        } ?? NSScreen.main
    }

    // MARK: - Reference data

    /// The live, resolved bindings for the currently-active mode.
    /// Nil when the panel can't read them (config owned by
    /// init.lua, or the engine isn't running) — the view then
    /// shows its "managed by init.lua" placeholder.
    private func buildReference() -> ShortcutsReference? {
        guard let snapshot = core.liveKeybindingSnapshot() else {
            return nil
        }
        let mode =
            snapshot.keyModes.first {
                $0.name == snapshot.activeModeName
            }
            ?? snapshot.keyModes.first
            ?? KeyMode.defaultMode
        let config = core.loadGuiConfig()
        return ShortcutsReferenceBuilder.build(
            mode: mode,
            spaces: config.spaces,
            spaceIcons: config.settings.spaceIcons,
            resizeStep: Int(config.settings.resizeStep),
            modeNames: snapshot.keyModes.map(\.name)
        )
    }

    // MARK: - NSWindowDelegate

    /// Click-away dismissal: losing key closes the panel, the
    /// Character-Viewer / Quick-Look dismissal gesture.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
