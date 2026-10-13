import AppKit
import KiwiDeskCore
import SwiftUI
import os

/// Diagnostic logging for the panel's show, pick and close.
/// `privacy: .public`, or macOS redacts every line (#951).
private let jumpLog = Logger(
    subsystem: KiwiLog.subsystem,
    category: "gui"
)

/// Jump to window (#1875): a key panel centred on the current
/// screen, opened over a snapshot of every window KiwiDesk knows.
/// A pick closes it and hands the row to Core's `jump(to:)` or
/// `moveHere(_:)`; Esc, ⌘W and a click away close it.
@MainActor
final class JumpPanelController: NSObject, NSWindowDelegate {
    let core: KiwiCore
    /// The keyed show and the close's dismiss distrust (#952).
    let handBack: PanelHandBack
    var panel: JumpPanel?
    private var model: JumpModel?
    /// This opening; a fade a later show overtook orders nothing
    /// out.
    private var presence = PanelPresence()
    /// Seam for the system Reduce Motion flag (#565).
    var reduceMotion: () -> Bool = {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(core: KiwiCore) {
        self.core = core
        handBack = PanelHandBack(core: core)
        super.init()
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

    func show() {
        let screen = PanelHandBack.screenUnderPointer()
        let snapshot = core.jumpSnapshot()
        let model = JumpModel(
            snapshot: snapshot,
            icons: Self.icons(for: snapshot),
            rowCap: Self.rowCap(
                visibleHeight: screen?.visibleFrame.height ?? 900
            ),
            modifiers: NSEvent.modifierFlags
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        self.model = model
        let presence = PanelPresence()
        self.presence = presence
        wire(model, panel)
        let glass = core.tiler.settings.shortcutPanelLiquidGlass
        let width = Self.width(
            visibleWidth: screen?.visibleFrame.width ?? 1440
        )
        let root = JumpPanelView(
            model: model,
            liquidGlass: glass,
            presence: presence,
            width: width
        )
        let hosting = NSHostingView(
            rootView: LocaleScopedRoot { root }
                .environmentObject(LocalizationManager.shared)
        )
        // A field editor left by the last opening would keep the
        // keys from the new content's field.
        panel.makeFirstResponder(nil)
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        PanelHandBack.center(panel, on: screen)
        let front = PanelHandBack.frontmostBundleID()
        let rows = snapshot.entries.count
        jumpLog.log(
            "KiwiDesk: jump show; \(rows, privacy: .public) rows"
        )
        jumpLog.log("KiwiDesk: jump front \(front, privacy: .public)")
        handBack.present(panel) { [weak self, presence] in
            self?.presence === presence && !presence.leaving
        }
    }

    /// Closes the panel. No close arms the dismiss distrust: the
    /// panels are non-activating, so the window a close keys again
    /// is the one the user was in (owner ruling 2026-10-13).
    func close() {
        dismiss(distrusting: false)
    }

    /// Closes on a pick, then runs it — once: a click during the
    /// exit fade picks nothing.
    func pick(_ entry: JumpEntry, moveHere: Bool) {
        guard
            dismiss(
                distrusting: Self.distrustsHandoff(
                    pick: entry.pid,
                    own: ProcessInfo.processInfo.processIdentifier
                )
            )
        else { return }
        jumpLog.log(
            "KiwiDesk: jump pick; here \(moveHere, privacy: .public)"
        )
        guard moveHere else {
            core.jump(to: entry.target)
            return
        }
        core.moveHere(entry.target)
    }

    /// Whether a pick arms the own-window handoff distrust: never
    /// for our own window, whose focus report the distrust eats.
    static func distrustsHandoff(pick pid: pid_t, own: pid_t) -> Bool {
        pid != own
    }

    /// The one close; false where there is nothing to close. A
    /// close already fading refuses the resign-key it fires, and a
    /// panel already hidden has no blip to distrust.
    @discardableResult
    private func dismiss(distrusting: Bool) -> Bool {
        guard panel?.isVisible != false, !presence.leaving else {
            return false
        }
        handBack.release(distrusting: distrusting) { [weak self] in
            self?.fadeOut()
        }
        return true
    }

    /// Fades the panel out, then orders it out; it stops taking
    /// keys the moment the fade starts.
    private func fadeOut() {
        model?.leave()
        presence.fadeOut(panel, reduceMotion: reduceMotion()) {
            [weak self] in self?.presence === $0
        }
    }

    // MARK: - Construction

    /// Internal so `MainMenuTests` takes the production panel.
    func makePanel() -> JumpPanel {
        let panel = JumpPanel(
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
        // A deactivation hide would leave the panel to come back
        // with the next activation; the resign-key close owns it.
        panel.hidesOnDeactivate = false
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

    private func wire(_ model: JumpModel, _ panel: JumpPanel) {
        panel.onKey = { [weak model] in model?.handle($0) }
        panel.onModifiers = { [weak model] in
            model?.noteModifiers($0)
        }
        panel.onComposing = { [weak model] in
            model?.noteComposing($0)
        }
        model.onPick = { [weak self] entry, moveHere in
            self?.pick(entry, moveHere: moveHere)
        }
        model.onClose = { [weak self] in
            self?.close()
        }
        model.onAnnounce = { [weak panel] text in
            guard let panel else { return }
            NSAccessibility.post(
                element: panel,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: text,
                    .priority:
                        NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
        // The next turn: the hosting view has not re-laid the new
        // results out in the setter's own.
        model.onResultsChange = { [weak self] in
            DispatchQueue.main.async { self?.refit() }
        }
    }

    // MARK: - NSWindowDelegate

    /// The field takes the keys whenever the panel does.
    func windowDidBecomeKey(_ notification: Notification) {
        model?.requestFieldFocus()
    }

    func windowDidResignKey(_ notification: Notification) {
        jumpLog.log("KiwiDesk: jump resign key; open \(self.isOpen)")
        close()
    }
}
