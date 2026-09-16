import AppKit
import QuartzCore

/// The Monocle flip's overlay (#1391): one non-activating panel
/// over the Monocle surface — never the screen — carrying a
/// behind-window blur of the real windows and a whole-surface
/// plate that turns from the outgoing app's icon to the incoming
/// one's, the focus swapping beneath it at the turn's midpoint.
///
/// Public API, no permission: the compositor blurs what is
/// behind the panel, and the plate is drawn — the window's own
/// pixels would need Screen Recording, ruled out on the issue.
/// Every motion here is built by `BarMotion`, Core's one gate.
@MainActor
final class MonocleFlipOverlay {
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?
    private var midpoint: (() -> Void)?

    /// The Reduce Motion read the decision takes — live by
    /// default; `makeTestCore` pins it ON so a suite's commanded
    /// focus lands at once rather than at a midpoint, and a flip
    /// suite states the read itself.
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    /// Puts the panel on screen — live by default; a flip suite
    /// pins it inert so no panel flashes on the runner.
    var present: @MainActor (NSPanel) -> Void = {
        $0.orderFrontRegardless()
    }

    /// A window's icon, sized for the plate; nil where the app
    /// has none.
    struct Face {
        let icon: NSImage?
    }

    var isPlaying: Bool { panel != nil }

    /// Plays `plan`, calling `midpoint` once when the plate is
    /// edge-on — the moment the focus command runs — and tearing
    /// down after the fade-out. A play in flight is settled
    /// first, its midpoint performed if it had not fired.
    func play(
        _ plan: MonocleFlipPlan,
        from: Face,
        to: Face,
        cornerRadius: CGFloat,
        midpoint: @escaping () -> Void
    ) {
        settle()
        let primaryHeight = GeometryUtils.primaryHeight
        let cover = GeometryUtils.flip(
            plan.cover,
            primaryHeight: primaryHeight
        )
        let panel = makePanel(frame: cover)
        let root = panel.contentView!
        let reduceMotion = self.reduceMotion()
        let dark = isDarkAppearance
        let scale =
            NSScreen.screens.first { $0.frame.intersects(cover) }?
            .backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let blur = makeBlur(frame: root.bounds)
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
        let local = { (rect: CGRect) -> CGRect in
            let flipped = GeometryUtils.flip(
                rect,
                primaryHeight: primaryHeight
            )
            return flipped.offsetBy(
                dx: -cover.minX,
                dy: -cover.minY
            )
        }
        let fromRect = local(plan.from)
        let toRect = local(plan.to)
        let card = CALayer()
        card.frame = fromRect
        // Eye distance scales with the extent that rotates, or a
        // window-sized plate's edges fly off screen mid-turn.
        var perspective = CATransform3DIdentity
        let extent =
            plan.axis == .vertical ? fromRect.width : fromRect.height
        perspective.m34 = -1 / max(extent * 2, 700)
        card.sublayerTransform = perspective
        host.layer?.addSublayer(card)
        let front = MonocleFlipPlate.face(
            icon: from.icon,
            size: fromRect.size,
            cornerRadius: cornerRadius,
            dark: dark,
            scale: scale
        )
        let back = MonocleFlipPlate.face(
            icon: to.icon,
            size: toRect.size,
            cornerRadius: cornerRadius,
            dark: dark,
            scale: scale
        )
        // Both faces centred in the card: the plate lands on the
        // incoming window's issued frame, which shares the
        // outgoing one's centre (#677).
        front.position = CGPoint(
            x: fromRect.width / 2,
            y: fromRect.height / 2
        )
        back.position = front.position
        card.addSublayer(front)
        card.addSublayer(back)
        let axis = plan.axis == .vertical ? "y" : "x"
        let sign = Double(plan.sign)
        // The back face starts turned away and arrives at zero;
        // the front turns away in the same sense.
        back.transform = MonocleFlipPlate.rotation(
            axis: plan.axis,
            radians: -sign * .pi
        )
        front.add(
            BarMotion.flipTurn(
                axis: axis,
                from: 0,
                to: sign * .pi,
                duration: plan.duration,
                reduceMotion: reduceMotion
            ),
            forKey: "turn"
        )
        back.add(
            BarMotion.flipTurn(
                axis: axis,
                from: -sign * .pi,
                to: 0,
                duration: plan.duration,
                reduceMotion: reduceMotion
            ),
            forKey: "turn"
        )
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
        self.panel = panel
        present(panel)
        self.midpoint = midpoint
        schedule(after: plan.midpoint) { [weak self] in
            self?.fireMidpoint()
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + plan.total
        ) { [weak self] in
            guard let self, self.panel === panel else { return }
            self.settle()
        }
    }

    /// Ends a play in flight: performs an unfired midpoint, so
    /// the focus the user commanded still lands, and drops the
    /// panel at once. A no-op with nothing playing, so every
    /// command may call it ahead of its dispatch.
    func settle() {
        pending?.cancel()
        pending = nil
        fireMidpoint()
        panel?.orderOut(nil)
        panel = nil
    }

    private func fireMidpoint() {
        guard let midpoint else { return }
        self.midpoint = nil
        midpoint()
    }

    private func schedule(
        after delay: TimeInterval,
        _ body: @escaping () -> Void
    ) {
        let item = DispatchWorkItem(block: body)
        pending = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: item
        )
    }

    private var isDarkAppearance: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua
    }

    private func makePanel(frame: CGRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = BarPanel.level
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .transient,
        ]
        panel.animationBehavior = .none
        let root = NSView(frame: CGRect(origin: .zero, size: frame.size))
        root.wantsLayer = true
        panel.contentView = root
        return panel
    }

    private func makeBlur(frame: CGRect) -> NSVisualEffectView {
        let blur = NSVisualEffectView(frame: frame)
        blur.blendingMode = .behindWindow
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        return blur
    }
}
