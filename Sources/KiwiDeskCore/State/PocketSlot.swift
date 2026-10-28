import CoreGraphics
import Foundation

/// One window of the pocket (#2446, #2678): kept one key away.
/// Pocketed, it is tracked but filed in no Space, parked off-screen
/// and drawn on no bar; out, it is a float that renders on every
/// Space like a global sticky. A window just marked (#2675) is out
/// with no frames and no `cameFrom`. `StateCoordinator.pocket`
/// holds the slots; every reader asks `pocketPhase(of:)`.
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
    /// When it was last focused while out, as an order among the
    /// slots (higher is later; 0 never): `pocket` puts back the
    /// latest (#2678). A take-out counts as a focus.
    public var focusedAt: Int

    public init(
        window: WindowID,
        pid: pid_t? = nil,
        phase: Phase,
        frames: [String: CGRect] = [:],
        cameFrom: WindowID? = nil,
        focusedAt: Int = 0
    ) {
        self.window = window
        self.pid = pid
        self.phase = phase
        self.frames = frames
        self.cameFrom = cameFrom
        self.focusedAt = focusedAt
    }

    private enum CodingKeys: String, CodingKey {
        case window
        case pid
        case phase
        case frames
        case cameFrom = "came_from"
        case focusedAt = "focused_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        window = try c.decode(WindowID.self, forKey: .window)
        pid = try c.decodeIfPresent(pid_t.self, forKey: .pid)
        phase = try c.decode(Phase.self, forKey: .phase)
        frames = try c.decode([String: CGRect].self, forKey: .frames)
        cameFrom = try c.decodeIfPresent(WindowID.self, forKey: .cameFrom)
        // A 4.0.0 slot has none.
        focusedAt =
            try c.decodeIfPresent(Int.self, forKey: .focusedAt) ?? 0
    }
}
