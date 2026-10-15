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
        /// Space or a presentation in front, as the shelf last
        /// judged them (`noteStandDown`).
        var standDown: Set<DisplayID>
        /// Whether a WindowServer stream reports the target
        /// restacking; without one a sync re-stacks every time,
        /// as a ring does (`BorderManager.ordersOverlay`).
        var tracked: Bool
        /// The dim, 0...1.
        var dim: CGFloat
        /// Whether the plate blurs what it covers: the user's
        /// switch, stood down under Reduce transparency.
        var blur: Bool
        /// Whether the wallpaper stays clear, so a plate draws
        /// only over `windows` (#2103 ruling 17).
        var clearWallpaper: Bool
        /// The windows below the plates, front to back; empty
        /// where no mask is drawn.
        var windows: [VisionMask.Window]
    }

    /// Whether the mode is on.
    public internal(set) var isOn = false
    /// The machine half of the appearance switch; the bootstrap
    /// wires the live one.
    var appearanceSwitch = VisionAppearanceSwitch.inert()
    /// Hears every change of `isOn`; the GUI announces it.
    public var onChange: @MainActor (Bool) -> Void = { _ in }
    var plates: [DisplayID: any VisionPlateBackend] = [:]
    /// The target each plate was last ordered below: a plate
    /// re-stacks only when the focus moves, a settle pass asks, the
    /// target's own reorder event fires or a float lands, since
    /// every order is
    /// a WindowServer round trip on the switch path (#1925).
    private var stackedUnder: [DisplayID: CGWindowID] = [:]
    /// The mask each plate last took, so a pass that leaves it
    /// alone sets nothing.
    private var shapes: [DisplayID: CGPath?] = [:]
    /// The window the plates keep clear, as the last sync read it.
    private(set) var target: CGWindowID?
    /// What the plates stack under, as the last sync read it: the
    /// target's behind ring, else the target.
    private var below: CGWindowID?
    /// The shelf's per-screen stand-down, filed by `updateBars`
    /// once per pass so the plate reads no WindowServer itself.
    private(set) var standDown: Set<DisplayID> = []
    /// The Reduce Motion read the fades name (borders.md).
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    /// The one WindowServer list read a mask takes; both
    /// `makeTestCore` twins pin it empty.
    var listWindows: @MainActor () -> [FloatDetection.ListedWindow] = {
        KiwiCore.liveFrontWindows()
    }
    /// The windows the last list read found, front to back, nil
    /// until a mask needs it and again once none does.
    private(set) var listed: [FloatDetection.ListedWindow]?
    /// The listed windows KiwiDesk tracked at the read: their
    /// frames come from state, and one that has left it since —
    /// another Desktop's, a closed one's — is no other app's
    /// window to haze (#2103 PR A review).
    private(set) var trackedAtRead: Set<CGWindowID> = []

    /// Re-reads the WindowServer list where `refresh` asks or
    /// nothing is cached, noting which windows `tracks` names.
    func listedWindows(
        refresh: Bool,
        tracks: (CGWindowID) -> Bool
    ) -> [FloatDetection.ListedWindow] {
        if refresh || listed == nil {
            let read = listWindows()
            listed = read
            trackedAtRead = Set(read.map(\.number).filter(tracks))
        }
        return listed ?? []
    }

    /// Moves a listed window to the bounds its own event reported
    /// (CG coordinates), or drops it where `frame` is nil — it
    /// hid or closed. True where the cache changed.
    func noteListedWindow(_ number: CGWindowID, frame: CGRect?) -> Bool {
        guard var all = listed,
            let index = all.firstIndex(where: { $0.number == number })
        else { return false }
        if let frame {
            guard all[index].frame != frame else { return false }
            let old = all[index]
            all[index] = FloatDetection.ListedWindow(
                number: old.number,
                pid: old.pid,
                layer: old.layer,
                frame: frame
            )
        } else {
            all.remove(at: index)
        }
        listed = all
        return true
    }

    /// Whether an event owed the list a fresh read before the next
    /// re-mask (`KiwiCore.oweVisionReshape`).
    var listOwed = false

    /// Drops the cached list: no mask reads it.
    func forgetListedWindows() {
        listed = nil
        trackedAtRead = []
    }
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

    /// Files the shelf's stand-down verdict; true when it changed.
    func noteStandDown(_ displays: Set<DisplayID>) -> Bool {
        guard displays != standDown else { return false }
        standDown = displays
        return true
    }

    /// Draws `request`: every screen not standing down shows its
    /// plate below the target, re-stacked through the ring's own
    /// gate; with nothing focused, or off, every plate fades out.
    func sync(_ request: Request, reassert: Bool) {
        let motion = reduceMotion()
        let live = Set(request.screens.map(\.display))
        for (display, plate) in plates where !live.contains(display) {
            plate.hide(reduceMotion: true)
            plates[display] = nil
            stackedUnder[display] = nil
            shapes[display] = nil
        }
        target = request.target
        below = request.target.map { request.below ?? $0 }
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
            // Nothing focused, nothing to keep clear: no stale
            // stack under a window that left.
            guard let target = request.target, let below else {
                plates[display]?.hide(reduceMotion: motion)
                stackedUnder[display] = nil
                continue
            }
            let plate = plates[display] ?? makePlate()
            plates[display] = plate
            plate.update(
                frame: screen.frame,
                dim: request.dim,
                blur: request.blur
            )
            reshape(plate, on: screen, request)
            if BorderManager.ordersOverlay(
                reassert: reassert,
                needsOrder: stackedUnder[display] != target,
                tracked: request.tracked
            ) {
                plate.order(below: below)
                stackedUnder[display] = target
            }
            plate.show(reduceMotion: motion)
        }
    }

    /// Masks `plate` to what `request` shows on `screen`, only
    /// where that changed. Never orders (ruling 21).
    private func reshape(
        _ plate: any VisionPlateBackend,
        on screen: (display: DisplayID, frame: CGRect),
        _ request: Request
    ) {
        let shape = VisionMask.path(
            screen: screen.frame,
            clearWallpaper: request.clearWallpaper,
            windows: request.windows
        )
        guard shapes[screen.display] != .some(shape) else { return }
        shapes[screen.display] = .some(shape)
        plate.reshape(shape)
    }

    /// Re-masks every shown plate to `request`, ordering nothing:
    /// a window moved under a standing plate.
    func reshapeShown(_ request: Request) {
        guard isOn else { return }
        for screen in request.screens {
            guard let plate = plates[screen.display], plate.isShown
            else { continue }
            reshape(plate, on: screen, request)
        }
    }

    /// Re-stacks every shown plate after the target's reorder
    /// event has re-ordered its ring, under the same anchor the
    /// last sync chose.
    func restack(after window: CGWindowID) {
        guard isOn, window == target, let below else { return }
        for (display, plate) in plates where plate.isShown {
            plate.order(below: below)
            stackedUnder[display] = window
        }
    }

    /// Turns the mode off and drops every plate at once, saying
    /// nothing: a stop or a quit is no toggle to announce.
    func clear() {
        isOn = false
        for plate in plates.values { plate.hide(reduceMotion: true) }
        plates = [:]
        stackedUnder = [:]
        shapes = [:]
        forgetListedWindows()
        target = nil
        below = nil
    }

    private func makePlate() -> any VisionPlateBackend {
        #if DEBUG
            if let plateFactory { return plateFactory() }
        #endif
        return AppKitVisionPlate()
    }
}
