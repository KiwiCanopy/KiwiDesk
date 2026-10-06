import AppKit
import KiwiDeskCore
import SwiftUI

/// The slow-boot notice (#1715): a non-activating capsule near
/// KiwiDesk's menu-bar item, narrating the boot count past
/// `BootNoticeTimeline.threshold` and leaving by itself at ready.
/// It never takes focus or the mouse; design-decisions ▸ Boot
/// carries the ruling.
@MainActor
final class BootNoticeController {
    private let model = BootNoticeModel()
    private var timeline = BootNoticeTimeline()
    private var panel: NSPanel?
    private var showWork: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?
    private var total = 0

    /// Another surface narrates this boot — "What's new" after an
    /// update relaunch (#1667). Set before boot.
    var narratedElsewhere = false
    var tourShowing: () -> Bool = { false }
    var screenStandsDown: (NSScreen) -> Bool = { _ in false }
    var liquidGlass: () -> Bool = { true }
    var statusButton: () -> NSStatusBarButton? = { nil }
    var now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }

    /// AppKit keeps a visible panel alive past its owner (#1868).
    isolated deinit {
        showWork?.cancel()
        hideWork?.cancel()
        panel?.orderOut(nil)
    }

    func phase(_ phase: BootPhase) {
        if let line = BootCountText.line(for: phase) {
            model.line = line
        }
        if case .scanning(_, let count) = phase { total = count }
        if let due = timeline.phase(phase, at: now()) {
            schedule(&showWork, at: due) { [weak self] in
                self?.showIfDue()
            }
        }
        if model.visible, tourShowing() {
            hide()
            return
        }
        if case .ready = phase {
            showWork?.cancel()
            if let at = timeline.hideTime(readyAt: now()) {
                schedule(&hideWork, at: at) { [weak self] in
                    self?.hide()
                }
            }
        } else if model.visible {
            place()
        }
    }

    private func showIfDue() {
        guard timeline.showsAt(now()), !narratedElsewhere, !tourShowing()
        else { return }
        let screen = targetScreen()
        guard let screen, !screenStandsDown(screen) else { return }
        timeline.shown(at: now())
        model.liquidGlass = liquidGlass()
        model.width = fixedWidth()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        place()
        panel.orderFrontRegardless()
        model.visible = true
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: model.line,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
        )
    }

    private func hide() {
        guard model.visible else { return }
        model.visible = false
        let fade =
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 0 : BootNoticeModel.fade
        DispatchQueue.main.asyncAfter(deadline: .now() + fade) {
            [weak self] in
            guard let self, !self.model.visible else { return }
            self.panel?.orderOut(nil)
        }
    }

    /// Measured with the total in both slots, so the digits never
    /// jitter, and capped; the line truncates past the cap.
    private func fixedWidth() -> CGFloat {
        let widest =
            BootCountText.line(
                for: .scanning(scanned: total, total: total)
            ) ?? model.line
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: 11.5,
            weight: .medium
        )
        let text = (widest as NSString).size(
            withAttributes: [.font: font]
        ).width
        // Leading 8 + glyph 12 + spacing 4 + trailing 12.
        return min(ceil(text) + 36, 360)
    }

    private func place() {
        guard let panel, let screen = targetScreen() else { return }
        let size = CGSize(width: model.width, height: 26)
        let item = statusButton()?.window.flatMap { window in
            let frame = window.frame
            return window.occlusionState.contains(.visible)
                && BootNoticeAnchor.anchors(
                    item: frame,
                    screen: screen.frame,
                    notchGap: BootNoticeAnchor.notchGap(of: screen)
                ) ? frame : nil
        }
        let origin = BootNoticeAnchor.origin(
            size: size,
            screen: screen.frame,
            menuBar: BootNoticeAnchor.menuBarHeight(of: screen),
            item: item
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }

    /// The screen of the active menu bar, else the main one.
    private func targetScreen() -> NSScreen? {
        statusButton()?.window?.screen ?? NSScreen.screens.first
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = BarPanel.aboveLevel
        panel.collectionBehavior = [
            .canJoinAllSpaces, .transient, .ignoresCycle,
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        let model = self.model
        panel.contentView = NSHostingView(
            rootView: LocaleScopedRoot { BootNoticeView(model: model) }
                .environmentObject(LocalizationManager.shared)
        )
        return panel
    }

    private func schedule(
        _ slot: inout DispatchWorkItem?,
        at time: TimeInterval,
        _ body: @escaping @MainActor () -> Void
    ) {
        slot?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated(body) }
        slot = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, time - now()),
            execute: work
        )
    }
}
