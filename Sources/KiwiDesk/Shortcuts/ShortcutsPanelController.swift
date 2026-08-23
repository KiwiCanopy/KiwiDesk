import AppKit
import KiwiDeskCore
import SwiftUI

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
            dismissCombo: ShortcutsOpenBinding.comboGlyphs(
                core: core
            ),
            onEdit: { [weak self] in
                self?.close()
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
        // #952 diagnosis: name what held frontmost before the
        // summon steals activation — the window focus SHOULD
        // return there on close.
        let front = NSWorkspace.shared.frontmostApplication
        NSLog(
            "KiwiDesk: cheat sheet show; frontmost was %@",
            front?.bundleIdentifier ?? "none"
        )
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Re-summoning while open dismisses it (the menu row toggles),
    /// so there is a focus-independent close even if the pointer
    /// never leaves the panel.
    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            show()
        }
    }

    private func close() {
        // #952 diagnosis: after orderOut, macOS re-keys the
        // app's next window — log what it picked one turn
        // later, and which app is frontmost then. The steal
        // is expected exactly when our Settings window is the
        // pick.
        NSLog(
            "KiwiDesk: cheat sheet close; own key window %@",
            NSApp.keyWindow?.title ?? "none"
        )
        panel?.orderOut(nil)
        DispatchQueue.main.async {
            let front = NSWorkspace.shared
                .frontmostApplication
            NSLog(
                "KiwiDesk: after close; key %@, frontmost %@",
                NSApp.keyWindow?.title ?? "none",
                front?.bundleIdentifier ?? "none"
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
        close()
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

    /// The shortcuts for the active layer. Nil ONLY when the config
    /// is genuinely owned by `init.lua` (not GUI-managed) — the view
    /// then shows its "managed by init.lua" placeholder.
    ///
    /// Prefers the live, resolved snapshot (what Carbon actually has
    /// installed). When window management is paused — no Accessibility
    /// permission, or bindings not applied yet — there is no snapshot;
    /// for a GUI-managed config we fall back to the CONFIGURED layers
    /// from gui.json so the user still sees their shortcuts (defined,
    /// just not live right now) rather than a misleading placeholder.
    private func buildReference() -> ShortcutsReference? {
        let layers: [KeyLayer]
        let activeLayer: String
        let config: GuiConfig
        if let snapshot = core.liveKeybindingSnapshot() {
            // Live: the running engine's spaces match the resolved
            // bindings, so the live-overlaid config is correct.
            layers = snapshot.keyLayers
            activeLayer = snapshot.activeLayerName
            config = core.loadGuiConfig()
        } else if core.isGuiManaged,
            let raw = core.persistedGuiConfig()
        {
            // Paused (no Accessibility): the engine hasn't discovered
            // any spaces, so loadGuiConfig would overlay an EMPTY live
            // space list and misfile every space shortcut into Custom.
            // Read the persisted gui.json directly — it keeps the
            // authored spaces and layers.
            layers = raw.layers
            activeLayer = raw.layers.first?.name ?? KeyLayer.defaultName
            config = raw
        } else {
            return nil
        }
        let layer =
            layers.first { $0.name == activeLayer }
            ?? layers.first
            ?? KeyLayer.defaultLayer
        // Two-source read: the layers supply the bindings; the config
        // supplies only spaces / icons / step, used to *generate
        // candidate preset rows* that are then intersected with the
        // actual bindings. A transient disagreement (space or step
        // edited but not yet re-applied) can only misfile a binding
        // — never hide or invent one — which stays safe for a
        // read-only glance panel. Since #820 the misfile can land
        // in Inactive as well as Custom, and that band's caption
        // ASSERTS the Space has left the list; the window is the
        // beat between a space edit and its apply, and it closes
        // itself, exactly as the Custom misfile does.
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            spaces: config.spaces,
            spaceIcons: config.settings.spaceIcons,
            resizeStep: Int(config.settings.resizeStep),
            layerNames: layers.map(\.name)
        )
        return withAppGlyphs(
            reference,
            settings: config.settings
        )
    }

    /// #294: when the bar renders App Font glyphs, the Apps
    /// band leads with the same glyph; apps without one keep
    /// their bundle icon. Deliberately keyed on the GLOBAL
    /// symbol style — the panel spans all layouts, so a
    /// Lua-only per-layout override can't (and shouldn't)
    /// steer it.
    private func withAppGlyphs(
        _ reference: ShortcutsReference,
        settings: TilingSettings
    ) -> ShortcutsReference {
        let source = settings.appBarStyle.iconSource
        // Allocation early-out only — the authoritative gate
        // lives in the resolver; mapping through it with an
        // image source would just write nils.
        guard source == .appFont else { return reference }
        var out = reference
        out.apps = reference.apps.map { row in
            var row = row
            row.glyph = core.appFont.glyph(
                forAppName: row.label,
                source: source
            )
            return row
        }
        return out
    }

    // MARK: - NSWindowDelegate

    /// Click-away dismissal: losing key closes the panel, the
    /// Character-Viewer / Quick-Look dismissal gesture.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
