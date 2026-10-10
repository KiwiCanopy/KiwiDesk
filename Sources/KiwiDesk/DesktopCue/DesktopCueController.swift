import AppKit
import KiwiDeskCore
import SwiftUI

/// The Desktop switch cue (#2142): a non-activating plate centred
/// on the screen KiwiDesk just switched, held `DesktopCueModel
/// .hold` and faded out. Another switch while it is up swaps the
/// content and restarts the hold. It never takes focus or the
/// mouse; the issue body carries the ruling.
@MainActor
final class DesktopCueController {
    private let model = DesktopCueModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var orderOutWork: DispatchWorkItem?

    var screenStandsDown: (NSScreen) -> Bool = { _ in false }
    var liquidGlass: () -> Bool = { true }

    /// AppKit keeps a visible panel alive past its owner (#1868).
    isolated deinit {
        hideWork?.cancel()
        orderOutWork?.cancel()
        panel?.orderOut(nil)
    }

    func show(_ cue: DesktopSwitchCue) {
        guard let screen = Self.screen(of: cue.display),
            !screenStandsDown(screen)
        else { return }
        orderOutWork?.cancel()
        model.cue = cue
        model.liquidGlass = liquidGlass()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let room = DesktopCueModel.room
        panel.setFrame(
            CGRect(
                x: screen.frame.midX - room.width / 2,
                y: screen.frame.midY - room.height / 2,
                width: room.width,
                height: room.height
            ),
            display: true
        )
        panel.orderFrontRegardless()
        model.visible = true
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: DesktopCueModel.spoken(cue),
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
        schedule(&hideWork, after: DesktopCueModel.hold) {
            [weak self] in self?.hide()
        }
    }

    private func hide() {
        model.visible = false
        let fade =
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 0 : DesktopCueModel.fade
        schedule(&orderOutWork, after: fade) { [weak self] in
            guard let self, !self.model.visible else { return }
            self.panel?.orderOut(nil)
        }
    }

    private static func screen(of display: DisplayID) -> NSScreen? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first {
            ($0.deviceDescription[key] as? NSNumber)?.uint32Value
                == display.raw
        }
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
            rootView: LocaleScopedRoot { DesktopCueView(model: model) }
                .environmentObject(LocalizationManager.shared)
        )
        return panel
    }

    private func schedule(
        _ slot: inout DispatchWorkItem?,
        after delay: TimeInterval,
        _ body: @escaping @MainActor () -> Void
    ) {
        slot?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated(body) }
        slot = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: work
        )
    }
}
