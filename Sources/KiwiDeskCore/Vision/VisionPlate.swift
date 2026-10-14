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
    /// Orders the plate in directly below `window`.
    func order(below window: CGWindowID)
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
    private let dimLayer = CALayer()
    /// The behind-window blur: Liquid Glass `clear` pinned dark,
    /// `hud` where glass cannot draw (#2103 ruling 10, amended
    /// 2026-10-14).
    private let blurView = AppKitVisionPlate.makeBlur()
    private(set) var isShown = false
    /// Bumped per show and hide, so a fade-out that lands after a
    /// later show leaves the panel ordered in.
    private var generation = 0

    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    /// The plate's fade, on and off.
    static let fadeDuration: CFTimeInterval = 0.2

    #if DEBUG
        /// The panel's window number, nil before the first update.
        var panelNumber: Int? { panel?.windowNumber }
        /// The panel's Spaces and Exposé behaviour.
        var panelBehavior: NSWindow.CollectionBehavior? {
            panel?.collectionBehavior
        }
    #endif

    func update(frame: CGRect, dim: CGFloat, blur: Bool) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if panel.frame != frame {
            panel.setFrame(frame, display: false)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dimLayer.frame = CGRect(origin: .zero, size: frame.size)
        blurView.frame = CGRect(origin: .zero, size: frame.size)
        dimLayer.opacity = Float(min(max(dim, 0), 1))
        CATransaction.commit()
        if blurView.isHidden == blur { blurView.isHidden = !blur }
    }

    /// AppKit's order: WindowServer applies no SkyLight order to
    /// an AppKit panel (#1962).
    func order(below window: CGWindowID) {
        panel?.order(.below, relativeTo: Int(window))
    }

    func show(reduceMotion: Bool) {
        guard !isShown, let layer = panel?.contentView?.layer
        else { return }
        isShown = true
        generation += 1
        fade(layer, to: 1, reduceMotion: reduceMotion) {}
    }

    func hide(reduceMotion: Bool) {
        guard isShown, let layer = panel?.contentView?.layer
        else { return }
        isShown = false
        generation += 1
        let fadeOut = generation
        fade(layer, to: 0, reduceMotion: reduceMotion) { [weak self] in
            guard let self, self.generation == fadeOut else { return }
            self.panel?.orderOut(nil)
        }
    }

    private func fade(
        _ layer: CALayer,
        to target: Float,
        reduceMotion: Bool,
        then done: @escaping @MainActor () -> Void
    ) {
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

    private func makePanel() -> NSPanel {
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
        // The ring's band: stacked relative to the focused window.
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // Every Desktop: the dim stays put while a Desktop
        // switch slides the windows under it. `.transient` hides
        // it in Mission Control (#1917).
        panel.collectionBehavior = [
            .transient,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        let view = NSView()
        view.wantsLayer = true
        view.layer?.opacity = 0
        blurView.isHidden = true
        blurView.autoresizingMask = [.width, .height]
        view.addSubview(blurView)
        // Above the blur: the dim darkens what the blur leaves.
        dimLayer.backgroundColor = NSColor.black.cgColor
        dimLayer.zPosition = 1
        view.layer?.addSublayer(dimLayer)
        panel.contentView = view
        return panel
    }

    /// The blur view a plate carries; glass where it can draw.
    static func makeBlur() -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .clear
            glass.cornerRadius = 0
            GlassTint.pinDark(glass)
            return glass
        }
        let hud = NSVisualEffectView()
        hud.material = .hudWindow
        hud.blendingMode = .behindWindow
        hud.state = .active
        return hud
    }
}
