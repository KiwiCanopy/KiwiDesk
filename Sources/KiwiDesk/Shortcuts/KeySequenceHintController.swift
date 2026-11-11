import AppKit
import KiwiDeskCore
import SwiftUI

/// The key sequence hint panel's window (#1871 ▸ hint panel): a
/// non-activating plate on the screen under the pointer, shown once
/// a sequence has stayed open `delay`, with no timeout once up. Its
/// top stands where KiwiHub's does and it grows down, so a step
/// never moves the header (#3175). It never takes focus; it takes
/// the scroll wheel, and a click closes the sequence through the
/// keyboard tap (#1871).
@MainActor
final class KeySequenceHintController {
    /// Before this, a sequence typed quickly shows nothing.
    static let delay: TimeInterval = 0.25

    private let core: KiwiCore
    private var panel: ActiveGlassPanel?
    private var showWork: DispatchWorkItem?
    /// The drawn step's scroll, which a scroll key moves.
    private var sheetScroll = KeySequenceHintScroll()
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

    /// A scroll key's press: the sheet moves, where it overflows.
    func scroll(_ scroll: KeySequenceScroll) {
        guard panel?.isVisible == true else { return }
        sheetScroll.take(scroll)
    }

    private func draw() {
        guard let (hint, reference) = hint(),
            let screen = PanelHandBack.screenUnderPointer() ?? NSScreen.main
        else { return }
        let glass = PanelGlass(settings: core.tiler.settings)
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.wearsActiveLook = glass.enabled && glass.wearsActiveLook
        let visible = screen.visibleFrame
        let area = JumpPanelController.clearArea(
            visible: visible,
            shelves: core.shelfFrames()
        )
        sheetScroll = KeySequenceHintScroll()
        let view = KeySequenceHintView(
            hint: hint,
            reference: reference,
            glass: glass,
            sheetCap: JumpPanelController.sheetCap(
                visible: visible,
                area: area
            ),
            scroll: sheetScroll
        )
        let host = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        let size = host.fittingSize
        panel.contentView = host
        panel.setFrame(
            CGRect(
                origin: JumpPanelController.origin(
                    size: size,
                    visible: visible,
                    area: area
                ),
                size: size
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
        // The wheel scrolls the sheet; a click reaches the tap first.
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        return panel
    }
}
