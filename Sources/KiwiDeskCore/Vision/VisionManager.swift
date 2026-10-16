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
        /// The target a lens holds under the haze (#2103 ruling
        /// 12): the plates order directly above it, nil otherwise.
        var holding: CGWindowID?
    }

    /// What the mode draws now.
    public internal(set) var active = VisionActive.off
    /// Whether the mode is on.
    public var isOn: Bool { active.isOn }
    /// The machine half of the appearance switch; the bootstrap
    /// wires the live one.
    var appearanceSwitch = VisionAppearanceSwitch.inert()
    /// Hears every change of `active` — on, off, or another lens —
    /// with its cause where the user did not ask for it; the GUI
    /// announces an on or an off.
    public var onChange:
        @MainActor (VisionActive, VisionChangeCause?) -> Void = {
            _,
            _ in
        }
    /// Hears a change of which lenses reach the live profile.
    public var onReachChange: @MainActor () -> Void = {}
    /// Hears each landing a lens holds, with the lens's own
    /// reminder, nil for the default; the GUI announces it.
    public var onHold: @MainActor (String?) -> Void = { _ in }
    /// The landing a lens holds under the haze now, nil while none
    /// waits; begun and ended only in `KiwiCore+VisionHold`.
    var hold: VisionHold?
    /// Whether the last sync drew the mode on a screen not standing
    /// down: a target change after one is a landing, the sync
    /// turning it on is not.
    private(set) var drewOn = false
    var plates: [DisplayID: any VisionPlateBackend] = [:]
    /// Where each plate was last ordered: a plate re-stacks only
    /// when the focus moves, a hold begins or ends, a settle pass
    /// asks, the target's own reorder event fires or a float
    /// lands, since every order is a WindowServer round trip on
    /// the switch path (#1925).
    private var stacked: [DisplayID: Stack] = [:]

    /// A plate's place: below the target, or above a held one.
    private struct Stack: Equatable {
        var target: CGWindowID
        var above: Bool
    }
    /// The mask each plate last took, so a pass that leaves it
    /// alone sets nothing.
    private var shapes: [DisplayID: CGPath?] = [:]
    /// What each plate's shape was built from: an unchanged input
    /// builds nothing, since a hole costs path booleans per window.
    private var shapeInputs: [DisplayID: ShapeInput] = [:]

    #if DEBUG
        /// Test-only: how many shapes the plates built.
        private(set) var shapeBuilds = 0
    #endif

    private struct ShapeInput: Equatable {
        var screen: CGRect
        var clearWallpaper: Bool
        var windows: [VisionMask.Window]
    }
    /// The window the plates keep clear, as the last sync read it.
    private(set) var target: CGWindowID?
    /// What the plates stack under, as the last sync read it: the
    /// target's behind ring, else the target.
    private var below: CGWindowID?
    /// Whether the last sync held its target, so a restack orders
    /// the plates above it.
    private var holding = false
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
    var listed: [FloatDetection.ListedWindow]?
    /// The listed windows KiwiDesk tracked at the read: their
    /// frames come from state, and one that has left it since —
    /// another Desktop's, a closed one's — is no other app's
    /// window to haze (#2103 PR A review).
    var trackedAtRead: Set<CGWindowID> = []
    /// The other apps' listed windows' corner radii, read with the
    /// list and replaced at each read, so the cache never outgrows
    /// the windows on screen.
    var listedRadii: [CGWindowID: CGFloat] = [:]
    /// Each listed process's bundle id (nil for a process without
    /// one), read with the list and kept per pid across reads, so
    /// a pass names an app without asking LaunchServices and a
    /// read asks only of a process it has not seen (#1936).
    var listedBundles: [pid_t: String?] = [:]

    /// Whether an event owed the list a fresh read before the next
    /// re-mask (`KiwiCore.oweVisionReshape`).
    var listOwed = false

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
            stacked[display] = nil
            shapes[display] = nil
            shapeInputs[display] = nil
        }
        target = request.target
        below = request.target.map { request.below ?? $0 }
        holding = request.holding != nil && request.holding == target
        drewOn = isOn && !live.isSubset(of: request.standDown)
        guard isOn else {
            for plate in plates.values { plate.hide(reduceMotion: motion) }
            stacked = [:]
            return
        }
        for screen in request.screens {
            let display = screen.display
            if request.standDown.contains(display) {
                plates[display]?.hide(reduceMotion: motion)
                stacked[display] = nil
                continue
            }
            // Nothing focused, nothing to keep clear: no stale
            // stack under a window that left.
            guard let target = request.target, let below else {
                plates[display]?.hide(reduceMotion: motion)
                stacked[display] = nil
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
            let stack = Stack(target: target, above: holding)
            if BorderManager.ordersOverlay(
                reassert: reassert,
                needsOrder: stacked[display] != stack,
                tracked: request.tracked
            ) {
                order(plate, stack, below: below)
                stacked[display] = stack
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
        let input = ShapeInput(
            screen: screen.frame,
            clearWallpaper: request.clearWallpaper,
            windows: request.windows
        )
        guard shapeInputs[screen.display] != input else { return }
        shapeInputs[screen.display] = input
        #if DEBUG
            shapeBuilds += 1
        #endif
        let shape = VisionMask.path(
            screen: input.screen,
            clearWallpaper: input.clearWallpaper,
            windows: input.windows
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
        let stack = Stack(target: window, above: holding)
        for (display, plate) in plates where plate.isShown {
            order(plate, stack, below: below)
            stacked[display] = stack
        }
    }

    /// The one place a plate orders: above a held target — its
    /// app's activation lifts the window back over the plate, so
    /// each reorder re-orders it (v3 probe P9) — else below
    /// `below`.
    private func order(
        _ plate: any VisionPlateBackend,
        _ stack: Stack,
        below: CGWindowID
    ) {
        if stack.above {
            plate.order(above: stack.target)
        } else {
            plate.order(below: below)
        }
    }

    /// Turns the mode off and drops every plate at once, saying
    /// nothing: a stop or a quit is no toggle to announce.
    func clear() {
        active = .off
        for plate in plates.values { plate.hide(reduceMotion: true) }
        plates = [:]
        stacked = [:]
        shapes = [:]
        shapeInputs = [:]
        forgetListedWindows()
        target = nil
        below = nil
        holding = false
        drewOn = false
    }

    private func makePlate() -> any VisionPlateBackend {
        #if DEBUG
            if let plateFactory { return plateFactory() }
        #endif
        return AppKitVisionPlate()
    }
}
