import AppKit

/// One float's KiwiVision panel (#2103 ruling 3): the production
/// `AppKitFloatDimPanel`, or a test double that owns no window.
@MainActor
protocol FloatDimBackend: AnyObject {
    /// Shown, or fading in.
    var isShown: Bool { get }
    /// Covers `frame` (AX coordinates) rounded to `cornerRadius`,
    /// at `dim`, 0...1, over a blur of what lies beneath where
    /// `blur`.
    func update(
        frame: CGRect,
        cornerRadius: CGFloat,
        dim: CGFloat,
        blur: Bool
    )
    /// Orders the panel in directly above `window`.
    func order(above window: CGWindowID)
    /// Fades in unless `reduceMotion`.
    func show(reduceMotion: Bool)
    /// Fades to dormant unless `reduceMotion`: transparent, still
    /// ordered in (borders.md ▸ the switch path).
    func hide(reduceMotion: Bool)
    /// Takes the panel off screen: its float was hidden.
    func orderOut()
    /// Fades out unless `reduceMotion`, then orders out for good:
    /// KiwiVision turned off.
    func retire(reduceMotion: Bool)
    /// Joins every Desktop while its float is carried (#2149).
    func setSpansDesktops(_ on: Bool)
}

/// The float panel's `.transient` AppKit panel: the plate's veil
/// over one float, its mark and its ring, joining one Desktop
/// unless the float is carried.
@MainActor
final class AppKitFloatDimPanel: FloatDimBackend {
    private var panel: NSPanel?
    private let veil = VisionVeil()
    private(set) var isShown = false

    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    #if DEBUG
        var panelBehavior: NSWindow.CollectionBehavior? {
            panel?.collectionBehavior
        }
    #endif

    func update(
        frame: CGRect,
        cornerRadius: CGFloat,
        dim: CGFloat,
        blur: Bool
    ) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let appKit = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        if panel.frame != appKit {
            panel.setFrame(appKit, display: false)
        }
        veil.update(
            size: appKit.size,
            dim: dim,
            blur: blur,
            cornerRadius: cornerRadius
        )
    }

    /// AppKit's order: WindowServer applies no SkyLight order to
    /// an AppKit panel (#1962).
    func order(above window: CGWindowID) {
        panel?.order(.above, relativeTo: Int(window))
    }

    func show(reduceMotion: Bool) {
        guard !isShown, panel != nil else { return }
        isShown = true
        veil.fade(to: 1, reduceMotion: reduceMotion) {}
    }

    func hide(reduceMotion: Bool) {
        guard isShown else { return }
        isShown = false
        veil.fade(to: 0, reduceMotion: reduceMotion) {}
    }

    func orderOut() {
        panel?.orderOut(nil)
    }

    func retire(reduceMotion: Bool) {
        isShown = false
        // Holds the panel through its fade-out.
        veil.fade(to: 0, reduceMotion: reduceMotion) { [self] in
            panel?.orderOut(nil)
        }
    }

    func setSpansDesktops(_ on: Bool) {
        if on {
            panel?.collectionBehavior.insert(.canJoinAllSpaces)
        } else {
            panel?.collectionBehavior.remove(.canJoinAllSpaces)
        }
    }

    private func makePanel() -> NSPanel {
        // One Desktop, the float's: `.transient` hides it in
        // Mission Control (#1917).
        let panel = VisionVeil.makePanel()
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.contentView = veil.view
        return panel
    }
}
