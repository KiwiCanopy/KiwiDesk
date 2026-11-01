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
    /// The app whose Pocket key owns the slot (#2612), lowercased;
    /// nil for the general list `pocket` works — the one answer to
    /// "has a key of its own". Stored as `owner`.
    public var keyedApp: String?

    public init(
        window: WindowID,
        pid: pid_t? = nil,
        phase: Phase,
        frames: [String: CGRect] = [:],
        cameFrom: WindowID? = nil,
        owner: String? = nil
    ) {
        self.window = window
        self.pid = pid
        self.phase = phase
        self.frames = frames
        self.cameFrom = cameFrom
        self.keyedApp = owner
    }

    private enum CodingKeys: String, CodingKey {
        case window
        case pid
        case phase
        case frames
        case cameFrom = "came_from"
        case keyedApp = "owner"
    }
}

/// What a `pocket_app` claim makes of an arriving window (#2612
/// ▸ 7), mirrored into the create fold: `claimed` skips its App
/// Rule; `awaited`, whose create is still due, keeps the rule but
/// earns no follow.
public enum PocketArrivalClaim: Sendable, Equatable {
    case claimed(WindowID)
    case awaited(WindowID)
}
