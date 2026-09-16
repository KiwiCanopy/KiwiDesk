import AppKit
import QuartzCore

/// The Monocle flip's overlay (#1391): one non-activating panel,
/// reused, over the Monocle surface — never the screen — with a
/// behind-window blur of the real windows and a whole-surface
/// plate turning from the outgoing app's icon to the incoming
/// one's. It holds no focus of its own: the landing callback
/// lands `KiwiCore.pendingMonocleFocus`. Every motion is
/// `BarMotion`'s.
@MainActor
final class MonocleFlipOverlay {
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?
    private var teardown: DispatchWorkItem?
    private var onLanding: (() -> Void)?
    private var incomingGlyph: CALayer?
    private var fading: [CALayer] = []
    private var scale: CGFloat = 2

    /// A window's icon; nil where the app has none.
    struct Face {
        let icon: NSImage?
    }

    /// The Reduce Motion read the decision takes — live by
    /// default; `makeTestCore` pins it ON so a suite's commanded
    /// focus lands at once rather than at a landing.
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    /// Puts the panel on screen — live by default; a flip suite
    /// pins it inert so no panel flashes on the runner.
    var present: @MainActor (NSPanel) -> Void = {
        $0.orderFrontRegardless()
    }

    var isPlaying: Bool { onLanding != nil || teardown != nil }

    /// Plays `plan`, calling `landing` once when the blur has
    /// covered the surface and tearing the panel down after the
    /// fade-out. A play in flight is ended first, its landing
    /// performed if it had not fired. `cornerRadii` are the
    /// outgoing and the incoming window's own.
    func play(
        _ plan: MonocleFlipPlan,
        from: Face,
        to: Face,
        cornerRadii: (from: CGFloat, to: CGFloat),
        landing: @escaping () -> Void
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
        self.scale = scale
        let local = { (rect: CGRect) -> CGRect in
            GeometryUtils.flip(rect, primaryHeight: primaryHeight)
                .offsetBy(dx: -cover.minX, dy: -cover.minY)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Blur and card share one morphing rounded cover: the
        // plate's near edge bulges under perspective, and
        // unclipped it draws a hard-edged slab past the window.
        let coverMask = { () -> CALayer in
            MonocleFlipPlate.cover(
                plan,
                fromRect: local(plan.from),
                toRect: local(plan.to),
                cornerRadii: cornerRadii,
                reduceMotion: reduceMotion
            )
        }
        let blur = Self.makeBlur(frame: root.bounds)
        blur.layer?.mask = coverMask()
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
        host.layer?.mask = coverMask()
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
        host.layer?.addSublayer(card.layer)
        incomingGlyph = card.incomingGlyph
        fading = [blur.layer, host.layer].compactMap { $0 }
        scheduleFadeOut(
            after: MonocleFlipPlan.fadeIn + plan.duration,
            reduceMotion: reduceMotion
        )
        CATransaction.commit()
        present(panel)
        onLanding = landing
        pending = schedule(after: plan.landing) { [weak self] in
            self?.fireLanding()
        }
    }

    /// Retargets a play in flight: the incoming face shows `to`
    /// from now on while the turn goes on, and the blur holds
    /// until the burst has been quiet for `MonocleFlipPlan.hold`
    /// — one motion rather than a restart per press.
    func retarget(to: Face) {
        guard let incomingGlyph else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        MonocleFlipPlate.repaint(
            incomingGlyph,
            icon: to.icon,
            scale: scale
        )
        for layer in fading {
            layer.removeAnimation(forKey: "out")
        }
        scheduleFadeOut(
            after: MonocleFlipPlan.hold,
            reduceMotion: reduceMotion()
        )
        CATransaction.commit()
    }

    /// The fade-out and the teardown behind it, `delay` from
    /// now; a retarget re-schedules both.
    private func scheduleFadeOut(
        after delay: TimeInterval,
        reduceMotion: Bool
    ) {
        for layer in fading {
            layer.add(
                BarMotion.flipFade(
                    from: 1,
                    to: 0,
                    duration: MonocleFlipPlan.fadeOut,
                    delay: delay,
                    reduceMotion: reduceMotion
                ),
                forKey: "out"
            )
        }
        teardown?.cancel()
        teardown = schedule(
            after: delay + MonocleFlipPlan.fadeOut
        ) { [weak self] in
            self?.end()
        }
    }

    /// Ends a play in flight: performs an unfired landing and
    /// drops the panel at once. A no-op with nothing playing.
    func end() {
        pending?.cancel()
        teardown?.cancel()
        pending = nil
        teardown = nil
        fireLanding()
        incomingGlyph = nil
        fading = []
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    private func fireLanding() {
        guard let onLanding else { return }
        self.onLanding = nil
        onLanding()
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
        // One Desktop's, unlike a bar: a Desktop switch leaves
        // the play behind rather than carrying it.
        panel.collectionBehavior = [
            .transient, .fullScreenAuxiliary, .ignoresCycle,
        ]
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
