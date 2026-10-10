import AppKit
import KiwiDeskCore
import SwiftUI

/// The slow-boot notice (#1715): a non-activating capsule near
/// KiwiDesk's menu-bar item, narrating the boot count past
/// `BootNoticeTimeline.threshold` and leaving by itself at ready —
/// or, after a restart, once its restore has put the windows back
/// (#2133).
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
    /// The restore's line while one runs; it outranks the boot
    /// count's (#2133).
    private var restoreLine: String?
    private var restoreTotal = 0

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
        if case .idle = phase {
            // A stop ends the boot, its restore with it.
            restoreLine = nil
            restoreTotal = 0
        }
        if case .scanning(_, let count) = phase { total = count }
        if let line = BootCountText.line(for: phase) {
            model.line = line
        } else if case .ready = phase, total > 0 {
            // The hold says the finished count, not the last tick.
            model.line =
                BootCountText.line(
                    for: .scanning(scanned: total, total: total)
                ) ?? model.line
        }
        if let restoreLine { model.line = restoreLine }
        apply(timeline.phase(phase, at: now(), standsDown: standsDown()))
    }

    /// The restart restore's progress (#2133): the same capsule
    /// changes its line, and its end is announced once.
    func restore(_ phase: RestorePhase) {
        let wasShown = model.visible
        if case .placing(_, let total) = phase { restoreTotal = total }
        restoreLine = BootCountText.line(for: phase)
        if let restoreLine {
            model.line = restoreLine
            if wasShown { widen() }
        }
        apply(
            timeline.restore(phase, at: now(), standsDown: standsDown())
        )
        if case .done = phase, wasShown, model.visible {
            announce(model.line, priority: .medium)
        }
        if case .none = phase { restoreLine = nil }
    }

    private func apply(_ effect: BootNoticeTimeline.Effect) {
        switch effect {
        case .none:
            if model.visible { place() }
        case .showAt(let due):
            schedule(&showWork, at: due) { [weak self] in
                self?.showIfDue()
            }
        case .cancel:
            showWork?.cancel()
        case .hideAt(let at):
            showWork?.cancel()
            schedule(&hideWork, at: at) { [weak self] in
                self?.hide()
            }
        case .hideNow:
            showWork?.cancel()
            hideWork?.cancel()
            hide()
        }
    }

    /// Re-read at every count update: a tour or a presentation
    /// that starts while the notice is up stands it down then.
    private func standsDown() -> Bool {
        narratedElsewhere || tourShowing()
            || targetScreen().map(screenStandsDown) ?? false
    }

    private func showIfDue() {
        guard timeline.showsAt(now(), standsDown: standsDown())
        else { return }
        timeline.shown(at: now())
        model.liquidGlass = liquidGlass()
        model.width = fixedWidth()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        place()
        panel.orderFrontRegardless()
        model.visible = true
        announce(model.line, priority: .high)
    }

    private func announce(
        _ line: String,
        priority: NSAccessibilityPriorityLevel
    ) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: line,
                .priority: priority.rawValue,
            ]
        )
    }

    /// A restore total larger than the width was measured for.
    private func widen() {
        let width = fixedWidth()
        guard width > model.width else { return }
        model.width = width
        place()
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

    /// The widest of the boot and restore lines, each measured with
    /// its total in both slots, so neither the digits nor the swap
    /// between them jitters; capped, the line truncating past it.
    private func fixedWidth() -> CGFloat {
        let count = max(total, restoreTotal)
        let lines = [
            BootCountText.line(
                for: .scanning(scanned: total, total: total)
            ),
            BootCountText.line(
                for: .placing(placed: count, total: count)
            ),
            BootCountText.line(for: .done(placed: count, total: count)),
            model.line,
        ].compactMap { $0 }
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: BootNoticeModel.textSize,
            weight: .medium
        )
        let widest =
            lines.map {
                ($0 as NSString).size(withAttributes: [.font: font]).width
            }.max() ?? 0
        return min(ceil(widest) + BootNoticeModel.chrome, 360)
    }

    private func place() {
        guard let panel, let screen = targetScreen() else { return }
        let size = CGSize(
            width: model.width,
            height: BootNoticeModel.height
        )
        // An auto-hidden bar still reports its item visible.
        let shown = NSMenu.menuBarVisible()
        let item = statusButton()?.window.flatMap { window in
            let frame = window.frame
            return shown && window.occlusionState.contains(.visible)
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

    /// The screen of the item's menu bar, else the active one.
    private func targetScreen() -> NSScreen? {
        statusButton()?.window?.screen ?? NSScreen.main
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
