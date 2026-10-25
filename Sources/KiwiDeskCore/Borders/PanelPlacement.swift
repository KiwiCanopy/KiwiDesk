import AppKit

/// Where an overlay panel that follows a window sits, and how it
/// gets there: the ring's and both marks' one placement (#1956,
/// #2531). A move that keeps the panel's size goes through
/// SkyLight, which WindowServer applies without the fence an
/// AppKit `setFrame` ties to the next commit — a fence that waits
/// up to ~500 ms on a slow app's held window transaction.
@MainActor
final class PanelPlacement {
    /// Moves a panel's window to a top-left origin; false means
    /// the move was not made.
    typealias Move = (CGWindowID, CGPoint) -> Bool

    /// The panel's frame of record, in AppKit coordinates. AppKit's
    /// own `panel.frame` lags a SkyLight move until WindowServer's
    /// moved event lands, so no decision reads it (#1956).
    private(set) var frame: CGRect?
    /// The main run loop pass in which AppKit last set the frame or
    /// first ordered the panel in; AppKit sends both at that pass's
    /// commit, over a SkyLight move issued before it (#1956).
    private var appKitPass: UInt64?
    /// Moves the panel's window to a top-left origin without
    /// AppKit's fence; false sends it through AppKit. Wired once,
    /// from `BorderManager.movePanel`.
    var movePanel: Move
    /// The main run loop's pass count (`MainRunLoopPass`).
    private let pass: @MainActor () -> UInt64
    #if DEBUG
        /// Test-only: panel frames handed to AppKit.
        private(set) var frameSets = 0
        /// Test-only: panel moves handed to SkyLight.
        private(set) var skyLightMoves = 0
    #endif

    init(
        movePanel: @escaping Move,
        pass: @escaping @MainActor () -> UInt64 = MainRunLoopPass.current
    ) {
        self.movePanel = movePanel
        self.pass = pass
    }

    /// Puts `panel` at `target` and returns the frame it took:
    /// through SkyLight once WindowServer has its window (a window
    /// number, kept through an order-out), AppKit has not set its
    /// frame or ordered it in this pass, and the size is kept; else
    /// through AppKit at `room` while that holds `target` (#1937).
    @discardableResult
    func place(
        _ panel: NSWindow,
        at target: CGRect,
        room: CGRect? = nil,
        display: Bool = false
    ) -> CGRect {
        if panel.windowNumber > 0, appKitPass != pass(),
            let placed = frame,
            placed.size == target.size,
            placed == target || move(panel, to: target)
        {
            frame = target
            return target
        }
        let next = Self.panelFrame(for: target, room: room)
        if next != frame {
            panel.setFrame(next, display: display)
            frame = next
            appKitPass = pass()
            #if DEBUG
                frameSets += 1
            #endif
        }
        return next
    }

    /// Runs an AppKit order of `panel`, stamping the pass when it
    /// creates the panel's window: AppKit sends that window's frame
    /// at this pass's commit, so a later SkyLight move would be lost.
    func order(_ panel: NSWindow, _ body: () -> Void) {
        let createsWindow = panel.windowNumber <= 0
        body()
        if createsWindow { appKitPass = pass() }
    }

    /// The panel's frame for `target`: `room` while it holds the
    /// whole target, else the target's own.
    nonisolated static func panelFrame(
        for target: CGRect,
        room: CGRect?
    ) -> CGRect {
        guard let room, room.contains(target) else { return target }
        return room
    }

    private func move(_ panel: NSWindow, to target: CGRect) -> Bool {
        let topLeft = GeometryUtils.flip(
            target,
            primaryHeight: GeometryUtils.primaryHeight
        ).origin
        guard movePanel(CGWindowID(panel.windowNumber), topLeft)
        else { return false }
        #if DEBUG
            skyLightMoves += 1
        #endif
        return true
    }
}
