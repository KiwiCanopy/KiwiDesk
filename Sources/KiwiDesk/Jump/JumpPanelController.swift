import AppKit
import KiwiDeskCore
import SwiftUI
import os

/// Diagnostic logging for the panel's activation and hand-back.
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
    /// The #952 activation hand-back.
    let handBack: PanelHandBack
    var panel: JumpPanel?
    private var model: JumpModel?
    private var closing = false
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

    var isOpen: Bool { panel?.isVisible == true }

    func toggle() {
        if isOpen {
            close(yieldingActivation: true)
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
        let front = handBack.capture()?.bundleIdentifier ?? "none"
        let rows = snapshot.entries.count
        jumpLog.log(
            "KiwiDesk: jump show; \(rows, privacy: .public) rows"
        )
        jumpLog.log("KiwiDesk: jump front \(front, privacy: .public)")
        handBack.present(panel)
    }

    /// Closes the panel; a keyboard-commanded close hands
    /// activation back (#952), a click away does not.
    func close(yieldingActivation: Bool) {
        dismiss(
            yielding: yieldingActivation,
            distrusting: yieldingActivation
        )
    }

    /// Closes on a pick, then runs it. A Move here Core refuses
    /// leaves no window to take the focus, so activation goes back
    /// to the app the user came from, as Esc would have.
    func pick(_ entry: JumpEntry, moveHere: Bool) {
        let target = dismiss(
            yielding: false,
            distrusting: Self.distrustsHandoff(
                pick: entry.pid,
                own: ProcessInfo.processInfo.processIdentifier
            )
        )
        jumpLog.log(
            "KiwiDesk: jump pick; here \(moveHere, privacy: .public)"
        )
        guard moveHere else {
            core.jump(to: entry.target)
            return
        }
        if !core.moveHere(entry.target), let target {
            handBack.activateReturnTarget(target)
        }
    }

    /// Whether a pick arms the own-window handoff distrust: never
    /// for our own window, whose focus report the distrust eats.
    static func distrustsHandoff(pick pid: pid_t, own: pid_t) -> Bool {
        pid != own
    }

    /// The one close. `closing` stops the resign-key that
    /// `orderOut` fires from closing a second time, and a panel
    /// already hidden has no blip to distrust nor target to give.
    @discardableResult
    private func dismiss(
        yielding: Bool,
        distrusting: Bool
    ) -> NSRunningApplication? {
        guard !closing, panel?.isVisible != false,
            !presence.leaving
        else { return nil }
        closing = true
        defer { closing = false }
        return handBack.release(
            yielding: yielding,
            distrusting: distrusting
        ) { [weak self] in
            self?.fadeOut()
        }
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
            self?.close(yieldingActivation: true)
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
            self?.close(yieldingActivation: true)
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
        close(yieldingActivation: false)
    }
}
