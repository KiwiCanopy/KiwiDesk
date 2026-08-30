import AppKit
import KiwiDeskCore
import SwiftUI
import os

/// Diagnostic logging for panel activation and hand-back (#952).
private let panelLog = Logger(
    subsystem: KiwiLog.subsystem,
    category: "gui"
)

private func logPanel(_ message: String) {
    panelLog.log("KiwiDesk: \(message, privacy: .public)")
}

/// Floating panel receiving keyboard events and dismissing on Esc or
/// click-away.
final class ShortcutsPanel: NSPanel {
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }
}

/// Controller for floating shortcuts reference overlay (#326, #952).
@MainActor
final class ShortcutsPanelController: NSObject, NSWindowDelegate {
    let core: KiwiCore
    private let onEdit: () -> Void
    private var panel: ShortcutsPanel?
    /// Previously frontmost application before summon stole activation (#952).
    var returnTarget: NSRunningApplication?
    /// Seam for activating return target application (#565).
    var activateReturnTarget: (NSRunningApplication) -> Void = {
        $0.activate()
    }
    /// Seam returning whether KiwiDesk is currently active app (#565).
    var isAppActive: () -> Bool = {
        NSApplication.shared.isActive
    }

    init(core: KiwiCore, onEdit: @escaping () -> Void) {
        self.core = core
        self.onEdit = onEdit
        super.init()
    }

    /// Whether close should yield activation back to previous app (#952).
    static func shouldYield(
        commanded: Bool,
        appActive: Bool,
        target: NSRunningApplication?
    ) -> Bool {
        commanded && appActive && target != nil
    }

    func show() {
        let reference = buildReference()
        let root = ShortcutsPanelView(
            reference: reference,
            dismissCombo: ShortcutsOpenBinding.comboGlyphs(
                core: core
            ),
            onEdit: { [weak self] in
                self?.close(yieldingActivation: false)
                self?.onEdit()
            }
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(
            rootView: LocaleScopedRoot { root }
                .environmentObject(LocalizationManager.shared)
        )
        resize(panel)
        center(panel)
        let frontmost = NSWorkspace.shared.frontmostApplication
        returnTarget =
            frontmost?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier
            ? nil : frontmost
        let front = frontmost?.bundleIdentifier ?? "none"
        logPanel("sheet show; front \(front)")
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if let panel, panel.isVisible {
            close(yieldingActivation: true)
        } else {
            show()
        }
    }

    /// Dismisses panel, optionally returning activation to prior app (#952).
    func close(yieldingActivation: Bool) {
        let key = NSApplication.shared.keyWindow?.title ?? "none"
        logPanel("sheet close; key \(key)")
        let target = returnTarget
        returnTarget = nil
        let active = isAppActive()
        if yieldingActivation, active {
            core.distrustOwnDismissHandoff()
        }
        panel?.orderOut(nil)
        if Self.shouldYield(
            commanded: yieldingActivation,
            appActive: active,
            target: target
        ), let target {
            activateReturnTarget(target)
        }
        DispatchQueue.main.async {
            let key = NSApplication.shared.keyWindow?.title ?? "none"
            let front =
                NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier ?? "none"
            logPanel("after close; key \(key)")
            logPanel("after close; front \(front)")
        }
    }

    /// Closes panel on keybinding layer switch (#603).
    func closeIfOpen() {
        guard let panel, panel.isVisible else { return }
        close(yieldingActivation: true)
    }

    // MARK: - Panel construction

    private func makePanel() -> ShortcutsPanel {
        let panel = ShortcutsPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
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
        panel.onCancel = { [weak self] in
            self?.close(yieldingActivation: true)
        }
        return panel
    }

    // MARK: - Sizing & placement

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

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        close(yieldingActivation: false)
    }
}
