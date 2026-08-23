import AppKit
import KiwiDeskCore
import SwiftUI
import os

/// #952 diagnosis lines. `Logger` + `privacy: .public`, never
/// `NSLog` — macOS redacts NSLog content to `<private>` in
/// `log show`, which blinds the capture (2026-08-23).
private let panelLog = Logger(
    subsystem: "com.kiwicanopy.kiwidesk",
    category: "gui"
)

/// A floating panel that closes on Esc and, via the controller's
/// resign-key handler, on click-away. Borderless, so it must opt
/// into key status (`canBecomeKey`) to receive the keystroke — and
/// the app is activated on show, or an accessory app's key window
/// never actually receives keyboard events.
final class ShortcutsPanel: NSPanel {
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    /// Explicit Esc handler as well as `cancelOperation` — a
    /// borderless panel hosting a SwiftUI view doesn't always route
    /// Esc through the cancel action, so catch the keystroke here
    /// too (53 = Escape).
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }
        super.keyDown(with: event)
    }
}

/// Owns the read-only shortcuts reference panel (#326). Retained by
/// `AppDelegate` so it survives close/reopen. Every show reads the
/// live keybinding snapshot fresh and re-centers on the screen
/// under the pointer — the panel has no placement of its own to
/// remember (a summoned reference, not a window the user parks).
@MainActor
final class ShortcutsPanelController: NSObject, NSWindowDelegate {
    // Internal, not private: `+Reference.swift` (a separate file,
    // split for the 350-line ceiling) reads it to build the
    // panel's content.
    let core: KiwiCore
    /// Opens Settings ▸ Shortcuts — the one bridge to editing.
    private let onEdit: () -> Void
    private var panel: ShortcutsPanel?
    /// The app frontmost before `show()` stole activation, to
    /// hand back on a keyboard-commanded close (#952). nil when
    /// the summon came from our own process (a Settings-window
    /// bridge) — that closes back to Settings naturally, and nil
    /// when nothing has been shown yet. Internal so a test can
    /// set it directly without calling `show()` (which activates
    /// the app and builds panels).
    var returnTarget: NSRunningApplication?
    /// Machine seam (#565 pattern): the live hand-back, so a
    /// test can record it instead of touching the real machine.
    var activateReturnTarget: (NSRunningApplication) -> Void = {
        $0.activate()
    }
    /// Machine seam, live by default: whether KiwiDesk is the
    /// active app, gating the yield in `close`. A test process
    /// is never the active app, so this is injectable —
    /// otherwise the yield gate could never be exercised true
    /// (the `frontmostPIDProvider` pattern, #565).
    var isAppActive: () -> Bool = {
        NSApplication.shared.isActive
    }

    init(core: KiwiCore, onEdit: @escaping () -> Void) {
        self.core = core
        self.onEdit = onEdit
        super.init()
    }

    /// Whether a close should hand activation back to `target`
    /// (#952): only a keyboard-commanded close (`commanded` —
    /// Escape, the toggle-close, `closeIfOpen`'s layer switch)
    /// while KiwiDesk is still the active app, with a remembered
    /// target. A click-away close (`windowDidResignKey`) passes
    /// `commanded: false` — the clicked app is already active,
    /// and re-activating the remembered one would fight it. Pure
    /// so all four arms are directly testable without NSApp.
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
                // A click, not a keyboard command, and its next
                // step is Settings — our own app — coming
                // forward, not the remembered app, so this does
                // not yield (#952).
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
        // Activate the app so a menu-bar (accessory) app's key window
        // actually receives keystrokes — without this, Esc and
        // click-away never fire and the panel can't be dismissed.
        // Accessory-level: no Dock icon appears (unlike the dashboard,
        // which promotes to regular). KiwiDesk's tiling hotkeys stay
        // global Carbon and keep firing while it's open; the panel is
        // a stateless summon that rebuilds its content on each open.
        // A layer switch while it's up auto-closes it (#603, see
        // closeIfOpen) rather than leaving another layer's bindings on
        // screen — reopen to see the new layer.
        // Remember what held frontmost before the summon steals
        // activation, so a keyboard-commanded close can hand it
        // back (#952) — UNLESS it is our own process (a summon
        // from Settings' Shortcuts row), which returns there
        // naturally without a re-activate.
        let frontmost = NSWorkspace.shared.frontmostApplication
        returnTarget =
            frontmost?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier
            ? nil : frontmost
        let front = frontmost?.bundleIdentifier ?? "none"
        panelLog.log(
            "KiwiDesk: sheet show; front \(front, privacy: .public)"
        )
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Re-summoning while open dismisses it (the menu row toggles),
    /// so there is a focus-independent close even if the pointer
    /// never leaves the panel.
    func toggle() {
        if let panel, panel.isVisible {
            close(yieldingActivation: true)
        } else {
            show()
        }
    }

    /// Orders the panel out. `yieldingActivation` is true for
    /// every keyboard-commanded close — Escape, this toggle-off,
    /// and `closeIfOpen`'s layer switch — where the user's focus
    /// context is the app `show()` remembered; `false` for
    /// `windowDidResignKey`, whose click-away has already
    /// activated the clicked app (#952 ruling). `returnTarget` is
    /// consumed (nilled) on every close, yielding or not, so a
    /// double close — this, then a resign-key close it triggers —
    /// cannot yield twice. Internal so a test can call it without
    /// `show()`, which activates the app and builds panels.
    func close(yieldingActivation: Bool) {
        // #952 diagnosis: after orderOut, macOS re-keys the
        // app's next window — log what it picked one turn
        // later, and which app is frontmost then. The steal
        // is expected exactly when our Settings window is the
        // pick.
        let key = NSApplication.shared.keyWindow?.title ?? "none"
        panelLog.log(
            "KiwiDesk: sheet close; key \(key, privacy: .public)"
        )
        // Consume the target BEFORE orderOut: ordering a key
        // panel out fires `windowDidResignKey`, whose re-entrant
        // `close(yieldingActivation: false)` would nil
        // `returnTarget` under this frame — leaving the Escape
        // yield dead in production while every test (which
        // orders out no real key panel) stays green.
        let target = returnTarget
        returnTarget = nil
        // Armed BEFORE orderOut: ordering the key panel out
        // blip-keys another own window (Settings) while the app
        // is still active, and AX's clickless re-report of it
        // lands after the yield below — the #952 residue the
        // dismiss grace consumes.
        core.distrustOwnDismissHandoff()
        panel?.orderOut(nil)
        if Self.shouldYield(
            commanded: yieldingActivation,
            appActive: isAppActive(),
            target: target
        ), let target {
            activateReturnTarget(target)
        }
        DispatchQueue.main.async {
            let key = NSApplication.shared.keyWindow?.title ?? "none"
            let front =
                NSWorkspace.shared.frontmostApplication?
                .bundleIdentifier ?? "none"
            panelLog.log(
                "KiwiDesk: after close; key \(key, privacy: .public)"
            )
            panelLog.log(
                "KiwiDesk: after close; front \(front, privacy: .public)"
            )
        }
    }

    /// Close the panel if it is open. Called when the active
    /// keybinding layer changes (#603): the panel is a per-open
    /// snapshot of one layer's bindings, so leaving it up after a
    /// switch would advertise shortcuts that are no longer active.
    /// Reopening (⌃⌥K) rebuilds it for the new layer.
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

    // MARK: - NSWindowDelegate

    /// Click-away dismissal: losing key closes the panel, the
    /// Character-Viewer / Quick-Look dismissal gesture. The
    /// click already activated whatever app it landed in, so
    /// this does not yield activation back (#952).
    func windowDidResignKey(_ notification: Notification) {
        close(yieldingActivation: false)
    }
}
