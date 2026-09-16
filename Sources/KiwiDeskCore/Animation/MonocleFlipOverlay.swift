import AppKit
import QuartzCore

/// The Monocle flip's overlay (#1391): one non-activating panel,
/// reused, over the Monocle surface — never the screen — with a
/// behind-window blur of the real windows and a whole-surface
/// plate turning from the outgoing app's icon to the incoming
/// one's. It holds no focus of its own: the midpoint callback
/// lands `KiwiCore.pendingMonocleFocus`. Every motion is
/// `BarMotion`'s.
@MainActor
final class MonocleFlipOverlay {
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?
    private var teardown: DispatchWorkItem?
    private var onMidpoint: (() -> Void)?

    /// A window's icon; nil where the app has none.
    struct Face {
        let icon: NSImage?
    }

    /// The Reduce Motion read the decision takes — live by
    /// default; `makeTestCore` pins it ON so a suite's commanded
    /// focus lands at once rather than at a midpoint.
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    /// Puts the panel on screen — live by default; a flip suite
    /// pins it inert so no panel flashes on the runner.
    var present: @MainActor (NSPanel) -> Void = {
        $0.orderFrontRegardless()
    }

    var isPlaying: Bool { onMidpoint != nil || teardown != nil }

    /// Plays `plan`, calling `midpoint` once when the plate is
    /// edge-on and tearing the panel down after the fade-out. A
    /// play in flight is ended first, its midpoint performed if
    /// it had not fired. `cornerRadii` are the outgoing and the
    /// incoming window's own.
    func play(
        _ plan: MonocleFlipPlan,
        from: Face,
        to: Face,
        cornerRadii: (from: CGFloat, to: CGFloat),
        midpoint: @escaping () -> Void
    ) {
        end()
        let primaryHeight = GeometryUtils.primaryHeight
        let cover = GeometryUtils.flip(
            plan.cover,
            primaryHeight: primaryHeight
        )
        let panel = self.panel ?? Self.makePanel()
        self.panel = panel
        panel.setFrame(cover, display: false)
        let root = NSView(
            frame: CGRect(origin: .zero, size: cover.size)
        )
        root.wantsLayer = true
        panel.contentView = root
        let reduceMotion = self.reduceMotion()
        let scale =
            NSScreen.screens.first { $0.frame.intersects(cover) }?
            .backingScaleFactor ?? 2
        let local = { (rect: CGRect) -> CGRect in
            GeometryUtils.flip(rect, primaryHeight: primaryHeight)
                .offsetBy(dx: -cover.minX, dy: -cover.minY)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let blur = Self.makeBlur(frame: root.bounds)
        root.addSubview(blur)
        blur.layer?.add(
            BarMotion.flipFade(
                from: 0,
                to: 1,
                duration: MonocleFlipPlan.fadeIn,
                delay: 0,
                reduceMotion: reduceMotion
            ),
            forKey: "in"
        )
        let host = NSView(frame: root.bounds)
        host.wantsLayer = true
        root.addSubview(host)
        let card = MonocleFlipPlate.card(
            plan,
            from: from,
            to: to,
            fromRect: local(plan.from),
            toRect: local(plan.to),
            cornerRadii: cornerRadii,
            dark: Self.isDarkAppearance,
            scale: scale,
            reduceMotion: reduceMotion
        )
        host.layer?.addSublayer(card)
        for layer in [blur.layer, host.layer] {
            layer?.add(
                BarMotion.flipFade(
                    from: 1,
                    to: 0,
                    duration: MonocleFlipPlan.fadeOut,
                    delay: MonocleFlipPlan.fadeIn + plan.duration,
                    reduceMotion: reduceMotion
                ),
                forKey: "out"
            )
        }
        CATransaction.commit()
        present(panel)
        onMidpoint = midpoint
        pending = schedule(after: plan.midpoint) { [weak self] in
            self?.fireMidpoint()
        }
        teardown = schedule(after: plan.total) { [weak self] in
            self?.end()
        }
    }

    /// Ends a play in flight: performs an unfired midpoint and
    /// drops the panel at once. A no-op with nothing playing.
    func end() {
        pending?.cancel()
        teardown?.cancel()
        pending = nil
        teardown = nil
        fireMidpoint()
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    private func fireMidpoint() {
        guard let onMidpoint else { return }
        self.onMidpoint = nil
        onMidpoint()
    }

    private func schedule(
        after delay: TimeInterval,
        _ body: @escaping () -> Void
    ) -> DispatchWorkItem {
        let item = DispatchWorkItem(block: body)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: item
        )
        return item
    }

    private static var isDarkAppearance: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua
    }

    private static func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        panel.ignoresMouseEvents = true
        return panel
    }

    private static func makeBlur(
        frame: CGRect
    ) -> NSVisualEffectView {
        let blur = NSVisualEffectView(frame: frame)
        blur.blendingMode = .behindWindow
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        return blur
    }
}
