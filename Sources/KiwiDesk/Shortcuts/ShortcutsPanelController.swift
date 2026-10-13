import AppKit
import KiwiDeskCore
import SwiftUI
import os

/// Diagnostic logging for the panel's show and close (#952).
private let panelLog = Logger(
    subsystem: KiwiLog.subsystem,
    category: "gui"
)

private func logPanel(_ message: String) {
    panelLog.log("KiwiDesk: \(message, privacy: .public)")
}

/// Floating panel receiving keyboard events and dismissing on Esc
/// or click-away. Borderless, so it opts into key status, and
/// non-activating, so it takes the keyboard without activating
/// KiwiDesk (#1875) — an ordinary panel of an accessory app
/// receives no keyboard events unless the app activates.
final class ShortcutsPanel: NSPanel {
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }

    /// Non-activating, so KiwiDesk's menu is not the one in the
    /// menu bar: the File and Edit chords — ⌘W's Close (#1533),
    /// the edit chords — are handed to it here, and nothing else.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        super.performKeyEquivalent(with: event)
            || MainMenu.performPanelChord(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    /// The File menu's Close (⌘W) is a keyboard-commanded close,
    /// so it closes like Esc. AppKit greys Close for a window
    /// without `.closable`, which a borderless panel is, so the
    /// item is validated here (#1533).
    override func performClose(_ sender: Any?) {
        onCancel()
    }

    override func validateUserInterfaceItem(
        _ item: any NSValidatedUserInterfaceItem
    ) -> Bool {
        if item.action == #selector(NSWindow.performClose(_:)) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    /// Esc explicitly as well as `cancelOperation` — a borderless
    /// panel hosting SwiftUI doesn't always route Esc through the
    /// cancel action (53 = Escape).
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
    /// The keyed show and the close's dismiss distrust (#952).
    let handBack: PanelHandBack
    /// This opening; a fade a later show overtook orders nothing
    /// out.
    private var presence = PanelPresence()
    /// Seam for the system Reduce Motion flag (#565).
    var reduceMotion: () -> Bool = {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(core: KiwiCore, onEdit: @escaping () -> Void) {
        self.core = core
        self.onEdit = onEdit
        handBack = PanelHandBack(core: core)
        super.init()
    }

    /// Whether the content exceeds the height ceiling — the ONE
    /// home for that verdict, so the footer's cue cannot
    /// disagree with the clamp that causes it (#1292).
    static func overflows(
        fitting: CGFloat,
        ceiling: CGFloat
    ) -> Bool {
        fitting > ceiling
    }

    func show() {
        let reference = buildReference()
        let onEdit: () -> Void = { [weak self] in
            // A click whose next step is Settings coming
            // forward: an intended focus, so the close arms no
            // dismiss distrust (#952).
            self?.close()
            self?.onEdit()
        }
        let combo = ShortcutsOpenBinding.comboGlyphs(core: core)
        let glass = core.tiler.settings.shortcutPanelLiquidGlass
        let presence = PanelPresence()
        self.presence = presence
        func view(overflows: Bool) -> ShortcutsPanelView {
            ShortcutsPanelView(
                presence: presence,
                reference: reference,
                dismissCombo: combo,
                overflows: overflows,
                liquidGlass: glass,
                onEdit: onEdit
            )
        }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        // The scoping stays spelled AT the call site: a named
        // wrapper type reads identically and is invisible to
        // `HostingRootLocaleScopeTests`, which scans this
        // initializer — and only this one, not the re-root below.
        let hosting = NSHostingView(
            rootView: LocaleScopedRoot { view(overflows: false) }
                .environmentObject(LocalizationManager.shared)
        )
        // A field editor left by the last opening would keep the
        // keys from the new content's field.
        panel.makeFirstResponder(nil)
        panel.contentView = hosting
        // Measured without the cue, re-rooted where it clipped;
        // no second measure (#1292).
        if resize(panel) {
            hosting.rootView =
                LocaleScopedRoot { view(overflows: true) }
                .environmentObject(LocalizationManager.shared)
        }
        PanelHandBack.center(
            panel,
            on: PanelHandBack.screenUnderPointer()
        )
        logPanel("sheet show; front \(PanelHandBack.frontmostBundleID())")
        handBack.present(panel) { [weak self, presence] in
            self?.presence === presence && !presence.leaving
        }
    }

    /// Up and not leaving: a toggle during the exit fade opens a
    /// new panel rather than closing one already going.
    var isOpen: Bool { panel?.isVisible == true && !presence.leaving }

    func toggle() {
        if isOpen {
            close()
        } else {
            show()
        }
    }

    /// Dismisses the panel. No close arms the dismiss distrust: the
    /// panels are non-activating, so the window a close keys again
    /// is the one the user was in (owner ruling 2026-10-13).
    func close() {
        guard !presence.leaving else { return }
        let key = NSApplication.shared.keyWindow?.title ?? "none"
        logPanel("sheet close; key \(key)")
        handBack.release(distrusting: false) { [weak self] in
            guard let self else { return }
            self.presence.fadeOut(
                self.panel,
                reduceMotion: self.reduceMotion()
            ) { [weak self] in self?.presence === $0 }
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
        guard isOpen else { return }
        close()
    }

    // MARK: - Panel construction

    /// Internal so `MainMenuTests` takes the production panel —
    /// its class and style mask are what the Close verdict is
    /// about (#1533).
    func makePanel() -> ShortcutsPanel {
        let panel = ShortcutsPanel(
            contentRect: .zero,
            styleMask: [
                .borderless, .fullSizeContentView, .nonactivatingPanel,
            ],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        // The view animates its own entrance and exit.
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary,
        ]
        panel.delegate = self
        panel.onCancel = { [weak self] in
            self?.close()
        }
        return panel
    }

    // MARK: - Sizing & placement

    /// Sizes the panel and reports whether it had to clip.
    private func resize(_ panel: ShortcutsPanel) -> Bool {
        guard let content = panel.contentView else { return false }
        let fitting = content.fittingSize
        let screen =
            PanelHandBack.screenUnderPointer()?.visibleFrame.height
            ?? fitting.height
        let ceiling = min(screen * 0.7, 720)
        let height = min(fitting.height, ceiling)
        panel.setContentSize(
            NSSize(width: fitting.width, height: height)
        )
        return Self.overflows(
            fitting: fitting.height,
            ceiling: ceiling
        )
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        logPanel("sheet resign key; open \(panel?.isVisible == true)")
        close()
    }
}
