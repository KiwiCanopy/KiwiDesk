import AppKit
import KiwiDeskCore
import SwiftUI

/// The switch cues' one plate (#2142, #2144): a non-activating
/// panel centred on the screen Core names, held `CuePlateModel
/// .hold` and faded out. Another cue while it is up swaps the
/// content and restarts the hold — a Desktop cue and a layout
/// cue replace each other rather than stack. It never takes
/// focus or the mouse; the issues carry the rulings.
@MainActor
final class CuePlateController {
    private let model = CuePlateModel()
    private var panel: ActiveGlassPanel?
    private var hideWork: DispatchWorkItem?
    private var orderOutWork: DispatchWorkItem?

    /// AppKit keeps a visible panel alive past its owner (#1868).
    isolated deinit {
        hideWork?.cancel()
        orderOutWork?.cancel()
        panel?.orderOut(nil)
    }

    /// `screen` is the one the cue's display names, resolved by
    /// Core; whether to show at all is Core's too. `glass` is
    /// KiwiHub's, read at the show (#2569).
    func show(
        _ content: CuePlateModel.Content,
        glass: PanelGlass,
        on screen: NSScreen
    ) {
        orderOutWork?.cancel()
        model.glass = glass
        model.present(
            content,
            reduceMotion: NSWorkspace.shared
                .accessibilityDisplayShouldReduceMotion
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.wearsActiveLook = glass.enabled && glass.wearsActiveLook
        let room = CuePlateModel.room
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
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: CuePlateModel.spoken(content),
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
        schedule(&hideWork, after: CuePlateModel.hold) {
            [weak self] in self?.hide()
        }
    }

    private func hide() {
        model.visible = false
        let fade =
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? 0 : CuePlateModel.fade
        schedule(&orderOutWork, after: fade) { [weak self] in
            guard let self, !self.model.visible else { return }
            self.panel?.orderOut(nil)
        }
    }

    private func makePanel() -> ActiveGlassPanel {
        let panel = ActiveGlassPanel(
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
            rootView: LocaleScopedRoot { CuePlateView(model: model) }
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
