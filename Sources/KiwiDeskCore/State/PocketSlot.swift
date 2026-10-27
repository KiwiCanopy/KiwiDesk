import CoreGraphics
import Foundation

/// The pocket (#2446): one window kept one key away. Pocketed, it
/// is tracked but filed in no Space, parked off-screen and drawn
/// on no bar; out, it is a float that renders on every Space like
/// a global sticky. A window just marked (#2675) is out with no
/// frames and no `cameFrom`. The one record of which window that
/// is — every reader asks `StateCoordinator.pocketPhase(of:)`.
public struct PocketSlot: Sendable, Equatable, Codable {
    public enum Phase: String, Sendable, Equatable, Codable {
        case pocketed
        case out
    }

    public var window: WindowID
    /// Its app's process, for a slot whose window is not tracked
    /// (an in-place relaunch, a hidden app): an exited process
    /// empties it.
    public var pid: pid_t?
    public var phase: Phase
    /// Where the window last sat out of the pocket, per screen,
    /// keyed by `Display.fingerprint`.
    public var frames: [String: CGRect]
    /// The window focused before it came out: the put-back's focus
    /// and KiwiVision's second clear window. Nil while pocketed and
    /// before its first take-out.
    public var cameFrom: WindowID?

    public init(
        window: WindowID,
        pid: pid_t? = nil,
        phase: Phase,
        frames: [String: CGRect] = [:],
        cameFrom: WindowID? = nil
    ) {
        self.window = window
        self.pid = pid
        self.phase = phase
        self.frames = frames
        self.cameFrom = cameFrom
    }

    private enum CodingKeys: String, CodingKey {
        case window
        case pid
        case phase
        case frames
        case cameFrom = "came_from"
    }
}
