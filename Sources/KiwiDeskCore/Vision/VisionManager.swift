import AppKit

/// KiwiVision (#2103): one plate per screen, stacked directly
/// below the focused window, so everything but that window dims.
/// A session value — a relaunch starts with it off.
@MainActor
public final class VisionManager {
    /// What `sync` draws: the screens, the window kept clear and
    /// the panel the plates stack under.
    struct Request {
        /// Each connected screen and its frame, AppKit
        /// coordinates.
        var screens: [(display: DisplayID, frame: CGRect)]
        /// The window kept clear, nil while nothing is focused.
        var target: CGWindowID?
        /// The window the plates order below — the target's ring
        /// where it sits behind the target, else the target.
        var below: CGWindowID?
        /// Screens standing the plate down: a native full-screen
        /// Space or a presentation in front.
        var standDown: Set<DisplayID>
        /// The dim, 0...1.
        var dim: CGFloat
    }

    /// Whether the mode is on.
    public internal(set) var isOn = false
    /// Hears every change of `isOn`; the GUI announces it.
    public var onChange: @MainActor (Bool) -> Void = { _ in }
    var plates: [DisplayID: any VisionPlateBackend] = [:]
    /// The target each plate was last ordered below: a plate
    /// re-stacks only when the focus moves, a settle pass asks or
    /// the target's own reorder event fires, since every order is
    /// a WindowServer round trip on the switch path (#1925).
    private var stackedUnder: [DisplayID: CGWindowID] = [:]
    /// The window the plates keep clear, as the last sync read it.
    private(set) var target: CGWindowID?
    /// The Reduce Motion read the fades name (borders.md).
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    #if DEBUG
        /// Test-only: builds plate backends. Every test core sets
        /// it to the inert plate, so a real panel needs its own
        /// manager.
        var plateFactory: (() -> any VisionPlateBackend)?
    #endif

    public init() {}

    /// Whether any plate is still shown or fading.
    var hasShownPlates: Bool {
        plates.values.contains { $0.isShown }
    }

    /// Draws `request`: every screen not standing down shows its
    /// plate below the target, re-stacked where the target moved
    /// or `reassert` asks; off, every plate fades out.
    func sync(_ request: Request, reassert: Bool) {
        let motion = reduceMotion()
        let live = Set(request.screens.map(\.display))
        for (display, plate) in plates where !live.contains(display) {
            plate.hide(reduceMotion: true)
            plates[display] = nil
            stackedUnder[display] = nil
        }
        target = request.target
        guard isOn else {
            for plate in plates.values { plate.hide(reduceMotion: motion) }
            stackedUnder = [:]
            return
        }
        for screen in request.screens {
            let display = screen.display
            if request.standDown.contains(display) {
                plates[display]?.hide(reduceMotion: motion)
                stackedUnder[display] = nil
                continue
            }
            let plate = plates[display] ?? makePlate()
            plates[display] = plate
            plate.update(frame: screen.frame, dim: request.dim)
            guard let target = request.target else { continue }
            if reassert || stackedUnder[display] != target {
                plate.order(below: request.below ?? target)
                stackedUnder[display] = target
            }
            plate.show(reduceMotion: motion)
        }
    }

    /// Re-stacks every shown plate under `window` after its own
    /// reorder event, ahead of its ring's re-order, which lands
    /// the ring between the two.
    func restack(below window: CGWindowID) {
        guard isOn, window == target else { return }
        for (display, plate) in plates where plate.isShown {
            plate.order(below: window)
            stackedUnder[display] = window
        }
    }

    /// Turns the mode off and drops every plate at once.
    func clear() {
        let wasOn = isOn
        isOn = false
        for plate in plates.values { plate.hide(reduceMotion: true) }
        plates = [:]
        stackedUnder = [:]
        target = nil
        if wasOn { onChange(false) }
    }

    private func makePlate() -> any VisionPlateBackend {
        #if DEBUG
            if let plateFactory { return plateFactory() }
        #endif
        return AppKitVisionPlate()
    }
}
