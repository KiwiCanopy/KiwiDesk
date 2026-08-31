import Foundation

/// Per-display native Desktop bookkeeping for Space switching (#888).
@MainActor
final class DesktopMemory {
    /// Remembered Space ID per native Desktop number and display UUID.
    var virtualSpaces: [String: [Int: SpaceID]] = [:]

    /// Last observed native Space ID per display (`KiwiCore+BootSeams`,
    /// docs/cli.md).
    var lastDisplaySpaces: [String: SkyLight.SpaceID] = [:]

    /// Seeds display space readings from desktop snapshot at boot.
    func seed(_ snapshot: DesktopSnapshot) {
        lastDisplaySpaces = snapshot.currentSpaces
    }
}
