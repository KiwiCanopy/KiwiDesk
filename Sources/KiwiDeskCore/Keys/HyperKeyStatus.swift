import Foundation

/// What the Hyper key's remap last did, as structure for the GUI
/// (#96, #1870).
public enum HyperKeyStatus: Sendable, Equatable {
    case on, off
    /// A key mapping KiwiDesk did not write is in place — named
    /// where it can be (#2470).
    case refused(HyperForeignRemap?)
    /// `hidutil` did not answer.
    case failed
}

/// The one foreign `UserKeyMapping` entry that refused the remap,
/// as keys the GUI can name (#2470);
/// `HyperKeyRemap.foreign(in:want:)` decides when there is one.
public struct HyperForeignRemap: Sendable, Equatable {
    public let source: HyperSourceKey
    public let destination: HyperSourceKey
    /// The entry is exactly the one KiwiDesk wants for the chosen
    /// key, so the user may take it over (#2471).
    public let claimable: Bool

    public init(
        source: HyperSourceKey,
        destination: HyperSourceKey,
        claimable: Bool = false
    ) {
        self.source = source
        self.destination = destination
        self.claimable = claimable
    }

}

extension HyperKeyStatus {
    /// ` (caps_lock -> f18)` for a named refusal, else empty: the
    /// English CLI reply and the log line share it.
    var foreignNote: String {
        guard case .refused(let foreign?) = self else { return "" }
        return " (\(foreign.source.rawValue) -> "
            + "\(foreign.destination.rawValue))"
    }
}
