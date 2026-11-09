import AppKit
import KiwiDeskCore
import SwiftUI

/// The key sequence hint panel's window (#1871 ▸ hint panel): a
/// non-activating plate on the screen under the pointer, shown once
/// a sequence has stayed open `delay`, with no timeout once up. It
/// never takes focus or the mouse: the keyboard tap reads every key
/// while a sequence is open.
@MainActor
final class KeySequenceHintController {
    /// Before this, a sequence typed quickly shows nothing.
    static let delay: TimeInterval = 0.25

    private let core: KiwiCore
    private var panel: ActiveGlassPanel?
    private var showWork: DispatchWorkItem?
    /// The step the panel draws or is about to.
    private(set) var progress: KeySequenceProgress?

    init(core: KiwiCore) {
        self.core = core
    }

    /// AppKit keeps a visible panel alive past its owner (#1868).
    isolated deinit {
        showWork?.cancel()
        panel?.orderOut(nil)
    }

    /// Core's one input: where the open sequence stands, nil once
    /// it closes.
    func follow(_ progress: KeySequenceProgress?) {
        let opened = self.progress == nil
        self.progress = progress
        guard progress != nil else {
            showWork?.cancel()
            panel?.orderOut(nil)
            return
        }
        if panel?.isVisible == true {
            draw()
        } else if opened {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.draw() }
            }
            showWork?.cancel()
            showWork = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.delay,
                execute: work
            )
        }
    }

    /// The hint for the step the sequence stands on, read from the
    /// installed tree; nil where that tree no longer holds it.
    func hint() -> (KeySequenceHint, ShortcutsReference?)? {
        guard let progress else { return nil }
        var found: KeySequenceHint?
        let running = core.runningKeySequence(leader: progress.leader)
        let reference = JumpPanelController.reference(core: core) { layer in
            found = KeySequenceHint.of(progress, in: layer)
            // The snapshot may lack a Lua sequence it could not read
            // back; the running tree still names every key.
            if found == nil, let running {
                var held = layer
                held.bindings.append(running)
                found = KeySequenceHint.of(progress, in: held)
            }
            return found?.endKeys
        }
        return found.map { ($0, reference) }
    }

    private func draw() {
        guard let (hint, reference) = hint(),
            let screen = PanelHandBack.screenUnderPointer() ?? NSScreen.main
        else { return }
        let glass = PanelGlass(settings: core.tiler.settings)
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.wearsActiveLook = glass.enabled && glass.wearsActiveLook
        let view = KeySequenceHintView(
            hint: hint,
            reference: reference,
            glass: glass
        )
        let host = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        let size = host.fittingSize
        panel.contentView = host
        let visible = screen.visibleFrame
        panel.setFrame(
            CGRect(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        panel.orderFrontRegardless()
        // The panel takes no focus, so VoiceOver hears the step.
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: hint.spokenBreadcrumb,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
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
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        return panel
    }
}
