import AppKit

/// On-window sticky mark overlay (#414, #421, ui-designer 2026-07-21).
@MainActor
final class StickyMarkOverlay {
    static let size: CGFloat = StickyMarkPlate.size
    static let inset: CGFloat = 6

    /// The pill's HUD timings are deliberately FIXED, not bound to
    /// the animation-duration setting (like macOS's own HUDs): the
    /// hold is a reading duration, and slowing window tiling must
    /// not make the pill crawl open. Only the snap-back `delay`
    /// tracks the setting, because it waits on a window animation.
    private static let expandDuration: TimeInterval = 0.22
    private static let holdDuration: TimeInterval = 1.6
    private static let collapseDuration: TimeInterval = 0.16

    private var panel: NSPanel?
    private let plate = StickyMarkPlate()
    private let target: CGWindowID
    /// Scope glyph (`infinity` or `pin.fill`, #445).
    private var symbolName = StickyStyle.symbolName
    private var currentWidth: CGFloat = size
    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private(set) var lastFrame: CGRect?

    init(window: CGWindowID) {
        target = window
    }

    /// Positions mark at top-right corner of `frame` (owner QA 2026-07-21).
    func update(frame: CGRect) {
        lastFrame = frame
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setFrame(
            markRect(for: frame, width: currentWidth),
            display: false
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// Stacks mark above target window.
    func order() {
        panel?.order(.above, relativeTo: Int(target))
    }

    /// Tints mark glyph (#429).
    func setMarkColor(_ hex: String) {
        plate.setMarkColor(hex)
    }

    /// Sets scope glyph symbol name (#445).
    func setSymbol(_ name: String) {
        guard name != symbolName else { return }
        symbolName = name
        if panel != nil { applySymbol() }
    }

    private func applySymbol() {
        plate.symbol.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: L(
                "sticky.mark.ax",
                "Sticky window"
            )
        )
    }

    func hide() {
        expandWork?.cancel()
        expandWork = nil
        collapseWork?.cancel()
        collapseWork = nil
        // Retire in the collapsed state so a later re-show cannot
        // resurrect the mark mid-pill.
        currentWidth = Self.size
        plate.setNameShown(false, animated: false, duration: 0)
        panel?.orderOut(nil)
    }

    /// Briefly expands mark into a pill after snap-back settles (#421).
    func flash(format: String, mark: SpaceMark, delay: TimeInterval) {
        guard panel != nil, lastFrame != nil else { return }
        expandWork?.cancel()
        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.expandThenHold(format: format, mark: mark)
        }
        expandWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, delay),
            execute: work
        )
    }

    private func expandThenHold(format: String, mark: SpaceMark) {
        guard let frame = lastFrame else { return }
        let width = min(
            plate.prepare(format: format, mark: mark),
            frame.width - Self.inset * 2
        )
        setPill(width: width, nameShown: true, on: frame)

        let work = DispatchWorkItem { [weak self] in
            guard let self, let frame = self.lastFrame else {
                return
            }
            self.setPill(
                width: Self.size,
                nameShown: false,
                on: frame
            )
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.holdDuration,
            execute: work
        )
    }

    private func setPill(
        width: CGFloat,
        nameShown: Bool,
        on frame: CGRect
    ) {
        currentWidth = width
        let rect = markRect(for: frame, width: width)
        guard let panel else { return }

        if reduceMotion {
            panel.setFrame(rect, display: true)
            plate.setNameShown(nameShown, animated: false, duration: 0)
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            let duration =
                nameShown
                ? Self.expandDuration : Self.collapseDuration
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(
                name: nameShown ? .easeOut : .easeIn
            )
            panel.animator().setFrame(rect, display: true)
            plate.setNameShown(
                nameShown,
                animated: true,
                duration: duration
            )
        }
        if nameShown { popEntrance() }
    }

    /// Entrance pop animation (#421, #436; ui-designer 2026-07-22).
    private func popEntrance() {
        guard let layer = plate.layer else { return }
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 1.045, 1.0]
        pop.keyTimes = [0, 0.45, 1.0]
        pop.duration = 0.13
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
        ]
        layer.add(pop, forKey: "entrancePop")
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion
    }

    private func markRect(
        for frame: CGRect,
        width: CGFloat
    ) -> CGRect {
        let mark = CGRect(
            x: frame.maxX - width - Self.inset,
            y: frame.minY + Self.inset,
            width: width,
            height: Self.size
        )
        return GeometryUtils.flip(
            mark,
            primaryHeight: GeometryUtils.primaryHeight
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(
                x: 0,
                y: 0,
                width: Self.size,
                height: Self.size
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // `.transient` hides the mark in Exposé/Mission Control at
        // the compositor level — it vanishes with the swipe, no
        // handler lag.
        panel.collectionBehavior = [
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        applySymbol()
        panel.contentView = plate
        return panel
    }
}
