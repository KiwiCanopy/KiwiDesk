import AppKit

/// The one Reduce Motion read in Core (#3238): macOS's setting, or
/// KiwiDesk's own Off (`animations.reduce_motion`), which inherits
/// its contract — motion drops, affordances stay. Every gate reads
/// `isOn` here; nothing else in Core asks NSWorkspace
/// (`ReduceMotionHomeTests`).
@MainActor
public enum ReduceMotion {
    #if DEBUG
        /// Test seam over the OS read; nil reads the machine.
        static var systemOverride: Bool? = nil
    #endif

    /// KiwiDesk's own Off, mirrored from the live app-wide values by
    /// `KiwiCore.appWideLiveChanged` alone.
    static var kiwiDesk = false

    /// Whether macOS asks for less motion.
    public static var system: Bool {
        #if DEBUG
            if let systemOverride { return systemOverride }
        #endif
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Whether KiwiDesk plays less motion: macOS's setting or its own.
    public static var isOn: Bool { joined(system: system, kiwiDesk: kiwiDesk) }

    /// The one join of the two reads, pure so a test needs no global.
    static func joined(system: Bool, kiwiDesk: Bool) -> Bool {
        system || kiwiDesk
    }
}
