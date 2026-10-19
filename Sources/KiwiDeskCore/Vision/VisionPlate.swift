import AppKit

/// One screen's KiwiVision plate (#2103): the production
/// `AppKitVisionPlate`, or a test double that owns no window.
@MainActor
protocol VisionPlateBackend: AnyObject {
    /// Shown, or fading in: the plate covers its screen.
    var isShown: Bool { get }
    /// Covers `frame` (AppKit coordinates) at `dim`, 0...1, over
    /// a blur of what lies beneath where `blur`.
    func update(frame: CGRect, dim: CGFloat, blur: Bool)
    /// Masks the plate to `path` (its own coordinates), nil for
    /// the whole screen. Never orders: a mask follows every pass,
    /// and an order is a WindowServer round trip (#1925).
    func reshape(_ path: CGPath?)
    /// Orders the plate in directly below `window`.
    func order(below window: CGWindowID)
    /// Orders the plate in directly above `window`: a lens holds
    /// it under the haze (#2103 ruling 12).
    func order(above window: CGWindowID)
    /// Fades `window`'s `region` (its own coordinates) from clear
    /// to the plate's dim and blur over `duration` seconds — the
    /// window focus left (#2417) — cut in under `reduceMotion`.
    /// Never orders.
    func fadeIn(
        _ region: CGPath,
        of window: CGWindowID,
        duration: CFTimeInterval,
        curve: VisionFadeCurve,
        reduceMotion: Bool
    )
    /// Fades the plate in unless `reduceMotion`.
    func show(reduceMotion: Bool)
    /// Fades the plate out unless `reduceMotion`, then orders it
    /// out.
    func hide(reduceMotion: Bool)
}

/// The plate's `.transient` AppKit panel: a black dim over its
/// whole screen, stacked below the focused window, so everything
/// under it dims and the menu bar, the Dock and the shelf, which
/// sit above the normal level, stay clear.
@MainActor
final class AppKitVisionPlate: VisionPlateBackend {
    private var panel: NSPanel?
    private let veil = VisionVeil()
    private(set) var isShown = false
    /// Bumped per show and hide, so a fade-out that lands after a
    /// later show leaves the panel ordered in.
    private var generation = 0

    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    #if DEBUG
        /// The panel's window number, nil before the first update.
        var panelNumber: Int? { panel?.windowNumber }
        /// The panel's Spaces and Exposé behaviour.
        var panelBehavior: NSWindow.CollectionBehavior? {
            panel?.collectionBehavior
        }
        /// Whether the blur view draws.
        var blurShown: Bool { veil.blurShown }
        /// Whether the dim draws above the blur.
        var dimAboveBlur: Bool { veil.dimAboveBlur }
        /// The mask the content takes, nil while it draws whole.
        var maskPath: CGPath? { veil.maskPath }
    #endif

    func update(frame: CGRect, dim: CGFloat, blur: Bool) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if panel.frame != frame {
            panel.setFrame(frame, display: false)
        }
        veil.update(size: frame.size, dim: dim, blur: blur, cornerRadius: 0)
    }

    func reshape(_ path: CGPath?) {
        veil.mask(path)
    }

    func fadeIn(
        _ region: CGPath,
        of window: CGWindowID,
        duration: CFTimeInterval,
        curve: VisionFadeCurve,
        reduceMotion: Bool
    ) {
        veil.fadeIn(
            region,
            of: window,
            duration: duration,
            timing: curve.timing,
            reduceMotion: reduceMotion
        )
    }

    /// AppKit's order: WindowServer applies no SkyLight order to
    /// an AppKit panel (#1962).
    func order(below window: CGWindowID) {
        panel?.order(.below, relativeTo: Int(window))
    }

    func order(above window: CGWindowID) {
        panel?.order(.above, relativeTo: Int(window))
    }

    func show(reduceMotion: Bool) {
        guard !isShown, panel != nil else { return }
        isShown = true
        generation += 1
        veil.fade(to: 1, reduceMotion: reduceMotion) {}
    }

    func hide(reduceMotion: Bool) {
        guard isShown, panel != nil else { return }
        isShown = false
        generation += 1
        let fadeOut = generation
        veil.fade(to: 0, reduceMotion: reduceMotion) { [weak self] in
            guard let self, self.generation == fadeOut else { return }
            self.panel?.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        // Every Desktop: the dim stays put while a Desktop
        // switch slides the windows under it. `.transient` hides
        // it in Mission Control (#1917).
        let panel = VisionVeil.makePanel()
        panel.collectionBehavior = [
            .transient,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        panel.contentView = veil.view
        return panel
    }
}

/// KiwiVision's look — a behind-window blur under a black dim —
/// and its fade, the one copy a plate draws (#2103).
@MainActor
final class VisionVeil {
    /// The panel's content view; transparent until `fade`.
    let view = NSView()
    let dimLayer = CALayer()
    /// Hosts the blur, so a leave fade masks it apart from the
    /// content (#2417).
    let blurHost = NSView()
    /// The mask the content rests at, nil for the whole view.
    private(set) var restingPath: CGPath?
    /// The leave fades in flight, nil while none runs.
    var fade: VisionVeilFade?
    /// The behind-window blur: Liquid Glass `clear` pinned dark,
    /// `hud` where glass cannot draw (#2103 ruling 10, amended
    /// 2026-10-14).
    private let blurView = VisionVeil.makeBlur()

    /// The fade, on and off.
    static let fadeDuration: CFTimeInterval = 0.2

    init() {
        view.wantsLayer = true
        view.layer?.opacity = 0
        blurView.isHidden = true
        blurView.wantsLayer = true
        blurHost.wantsLayer = true
        blurHost.addSubview(blurView)
        view.addSubview(blurHost)
        // Above the blur: the dim darkens what the blur leaves.
        dimLayer.backgroundColor = NSColor.black.cgColor
        dimLayer.zPosition = 1
        view.layer?.addSublayer(dimLayer)
    }

    #if DEBUG
        var blurShown: Bool { !blurView.isHidden }
        var dimAboveBlur: Bool {
            dimLayer.zPosition > (blurView.layer?.zPosition ?? 0)
        }
        var dimOpacity: Float { dimLayer.opacity }
        var cornerRadius: CGFloat { dimLayer.cornerRadius }
    #endif

    /// Draws `size` at `dim`, 0...1, over a blur of what lies
    /// beneath where `blur`, rounded to `cornerRadius`.
    func update(
        size: CGSize,
        dim: CGFloat,
        blur: Bool,
        cornerRadius: CGFloat
    ) {
        let bounds = CGRect(origin: .zero, size: size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimLayer.frame = bounds
        dimLayer.cornerRadius = cornerRadius
        if blurHost.frame != bounds { blurHost.frame = bounds }
        if blurView.frame != bounds { blurView.frame = bounds }
        GlassPlate.update(blurView, frame: bounds, cornerRadius: cornerRadius)
        // Glass rounds itself; the `hud` fallback is masked.
        if blurView is NSVisualEffectView {
            blurView.layer?.cornerRadius = cornerRadius
            blurView.layer?.masksToBounds = cornerRadius > 0
        }
        dimLayer.opacity = Float(VisionPlateDim.opacity(forDim: dim))
        CATransaction.commit()
        if blurView.isHidden == blur { blurView.isHidden = !blur }
    }

    /// Clips the dim and the blur to `path`, nil for the whole
    /// view: a layer mask on the content clips a behind-window
    /// blur too, Liquid Glass and `hud` alike (v2 probe P8).
    func mask(_ path: CGPath?) {
        restingPath = path
        // A fade in flight masks the dim and the blur itself.
        if fade != nil {
            layoutFade()
            return
        }
        guard let layer = view.layer else { return }
        guard let path else {
            layer.mask = nil
            return
        }
        let shape = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.frame = layer.bounds
        shape.fillColor = NSColor.black.cgColor
        shape.path = path
        CATransaction.commit()
        if layer.mask !== shape { layer.mask = shape }
    }

    #if DEBUG
        /// The mask's path, nil while the veil draws whole.
        var maskPath: CGPath? {
            (view.layer?.mask as? CAShapeLayer)?.path
        }
    #endif

    /// Fades the veil to `target` opacity, cut in under Reduce
    /// Motion, then calls `done`.
    func fade(
        to target: Float,
        reduceMotion: Bool,
        then done: @escaping @MainActor () -> Void
    ) {
        guard let layer = view.layer else { return }
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            MainActor.assumeIsolated { done() }
        }
        layer.removeAnimation(forKey: "fade")
        layer.add(
            BarMotion.opacityFade(
                from: layer.presentation()?.opacity ?? layer.opacity,
                to: target,
                begin: CACurrentMediaTime(),
                duration: Self.fadeDuration,
                reduceMotion: reduceMotion
            ),
            forKey: "fade"
        )
        layer.opacity = target
        CATransaction.commit()
    }

    /// The blur view a veil carries; glass where it can draw.
    static func makeBlur() -> NSView {
        if let glass = GlassPlate.make() {
            GlassPlate.update(glass, frame: .zero, cornerRadius: 0)
            GlassTint.pinDark(glass)
            return glass
        }
        let hud = NSVisualEffectView()
        hud.material = .hudWindow
        hud.blendingMode = .behindWindow
        hud.state = .active
        return hud
    }

    /// A click-through `.normal` panel for a veil, stacked relative
    /// to a window — the ring's band.
    static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
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
        return panel
    }
}

/// The plate's dim mapping (#2103): the one copy, read by the
/// plate's dim layer and the Settings picture's veil.
public enum VisionPlateDim {
    /// The dim layer's opacity for a dim of 0...1.
    public static func opacity(forDim dim: CGFloat) -> CGFloat {
        min(max(dim, 0), 1)
    }
}
