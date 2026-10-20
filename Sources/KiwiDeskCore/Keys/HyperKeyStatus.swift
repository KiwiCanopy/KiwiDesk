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
/// as keys the GUI can name (#2470). Nil where the mapping holds
/// several entries or a key outside `HyperSourceKey`, so a
/// reader falls back to the unnamed sentence.
public struct HyperForeignRemap: Sendable, Equatable {
    public let source: HyperSourceKey
    public let destination: HyperSourceKey

    public init(source: HyperSourceKey, destination: HyperSourceKey) {
        self.source = source
        self.destination = destination
    }

    init?(_ mapping: Set<HyperKeyRemap.Pair>) {
        guard mapping.count == 1, let pair = mapping.first,
            let source = HyperSourceKey(hidUsage: pair.source),
            let destination = HyperSourceKey(
                hidUsage: pair.destination
            )
        else { return nil }
        self.init(source: source, destination: destination)
    }

    /// `caps_lock -> f18`, for the English CLI refusal.
    var wireSpelling: String {
        "\(source.rawValue) -> \(destination.rawValue)"
    }
}
