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
    private var panel: JumpPanel?
    private var model: JumpModel?
    private var closing = false
    /// The app in front before the panel took activation (#952).
    var returnTarget: NSRunningApplication?
    /// Seam for activating the return target (#565).
    var activateReturnTarget: (NSRunningApplication) -> Void = {
        $0.activate()
    }
    /// Seam answering whether KiwiDesk is the active app (#565).
    var isAppActive: () -> Bool = {
        NSApplication.shared.isActive
    }

    init(core: KiwiCore) {
        self.core = core
        super.init()
    }

    /// The most rows the list shows: a third of the screen's
    /// visible height, never fewer than 6 nor more than 12.
    static func rowCap(visibleHeight: CGFloat) -> Int {
        let rows = Int(visibleHeight / 3 / JumpRowView.height)
        return min(max(rows, 6), 12)
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
        let screen = screenUnderPointer()
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
        wire(model, panel)
        let glass = core.tiler.settings.shortcutPanelLiquidGlass
        let hosting = NSHostingView(
            rootView: LocaleScopedRoot {
                JumpPanelView(model: model, liquidGlass: glass)
            }
            .environmentObject(LocalizationManager.shared)
        )
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        center(panel, on: screen)
        let frontmost = NSWorkspace.shared.frontmostApplication
        returnTarget =
            frontmost?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier
            ? nil : frontmost
        let front = frontmost?.bundleIdentifier ?? "none"
        let rows = snapshot.entries.count
        jumpLog.log(
            "KiwiDesk: jump show; \(rows, privacy: .public) rows"
        )
        jumpLog.log("KiwiDesk: jump front \(front, privacy: .public)")
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closes the panel, optionally returning activation to the
    /// app that was in front (#952) — only on a keyboard-commanded
    /// close; a pick or a click away activates something itself.
    func close(yieldingActivation: Bool) {
        dismiss(
            yielding: yieldingActivation,
            handoff: yieldingActivation
        )
    }

    /// Closes on a pick, then runs it. The orderOut's own-window
    /// focus blip is distrusted unless the pick is our own window,
    /// whose report the distrust would eat.
    func pick(_ entry: JumpEntry, moveHere: Bool) {
        dismiss(
            yielding: false,
            handoff: Self.distrustsHandoff(
                pick: entry.pid,
                own: ProcessInfo.processInfo.processIdentifier
            )
        )
        jumpLog.log(
            "KiwiDesk: jump pick; here \(moveHere, privacy: .public)"
        )
        if moveHere {
            core.moveHere(entry.target)
        } else {
            core.jump(to: entry.target)
        }
    }

    /// Whether a pick arms the own-window handoff distrust: never
    /// for our own window, whose focus report the distrust eats.
    static func distrustsHandoff(pick pid: pid_t, own: pid_t) -> Bool {
        pid != own
    }

    private func dismiss(yielding: Bool, handoff: Bool) {
        guard !closing, let panel, panel.isVisible else { return }
        closing = true
        defer { closing = false }
        // Consumed BEFORE orderOut, whose resign-key re-enters
        // here (`ShortcutsPanelController.close`, #952).
        let target = returnTarget
        returnTarget = nil
        let active = isAppActive()
        if handoff, active {
            core.distrustOwnDismissHandoff()
        }
        panel.orderOut(nil)
        model = nil
        if ShortcutsPanelController.shouldYield(
            commanded: yielding,
            appActive: active,
            target: target
        ), let target {
            activateReturnTarget(target)
        }
    }

    // MARK: - Construction

    /// Internal so `MainMenuTests` takes the production panel.
    func makePanel() -> JumpPanel {
        let panel = JumpPanel(
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

    private func wire(_ model: JumpModel, _ panel: JumpPanel) {
        panel.onKey = { [weak model] in model?.handle($0) }
        panel.onModifiers = { [weak model] in
            model?.noteModifiers($0)
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
        model.onResultsChange = { [weak self] in self?.refit() }
    }

    private static func icons(
        for snapshot: JumpSnapshot
    ) -> [pid_t: NSImage] {
        var icons: [pid_t: NSImage] = [:]
        for pid in Set(snapshot.entries.map(\.pid)) {
            icons[pid] =
                NSRunningApplication(processIdentifier: pid)?.icon
        }
        return icons
    }

    // MARK: - Sizing & placement

    /// Fits the panel to its list, keeping the top edge where it
    /// is so the field stays under the user's eyes.
    private func refit() {
        guard let panel, let content = panel.contentView else {
            return
        }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        let top = panel.frame.maxY
        panel.setFrame(
            NSRect(
                x: panel.frame.minX,
                y: top - size.height,
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }

    private func center(_ panel: JumpPanel, on screen: NSScreen?) {
        guard let screen else {
            panel.center()
            return
        }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
        )
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
