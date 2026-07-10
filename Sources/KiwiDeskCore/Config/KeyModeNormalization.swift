import Foundation

/// Decode-time normalization for untrusted mode lists (#31).
///
/// `[KeyMode]` enters from hand-editable JSON at exactly two
/// sites — `GuiConfig.modes` (the `gui.json` sidecar) and
/// `KeyModeOverride` (a profile's sparse `"modes"` override).
/// A hand-edited file can carry duplicate mode names, an icon
/// on the default mode, or empty names; every GUI entry point
/// blocks these, so decode is the one untrusted boundary.
///
/// Both `init(from:)` contexts are pure `Codable` — the
/// config-issue reporter is unreachable from there — so invalid
/// input is normalized silently and predictably instead of
/// rejected. Re-saving persists the normalized form; that is
/// the migration (AGENTS.md §5, pre-release). ONE shared helper
/// serves both sites so the rules cannot drift apart.
extension KeyMode {
    /// Normalizes a FULL mode list (`GuiConfig.modes`):
    /// `sanitized`, plus the always-present default mode is
    /// guaranteed to exist and sit first (the documented list
    /// convention; the GUI and the structured loader assume a
    /// default mode is available). Empty input therefore falls
    /// back to `[KeyMode.defaultMode]` — the pre-#31 behavior.
    public static func normalized(
        full modes: [KeyMode]
    ) -> [KeyMode] {
        var result = sanitized(modes)
        if let at = result.firstIndex(where: { $0.isDefault }) {
            if at != 0 {
                result.insert(result.remove(at: at), at: 0)
            }
        } else {
            result.insert(.defaultMode, at: 0)
        }
        return result
    }

    /// Normalizes a SPARSE override list (`KeyModeOverride`):
    /// `sanitized` only. A sparse list must NEVER gain a
    /// default entry — a missing mode means "inherit the base"
    /// (O4 soft), and order is preserved as stored.
    public static func normalized(
        sparse modes: [KeyMode]
    ) -> [KeyMode] {
        sanitized(modes)
    }

    /// The shared core, applied by both flavors:
    /// - drops modes with an empty name (never addressable —
    ///   the GUI cannot create, select, or delete them);
    /// - drops later duplicates of a name (first occurrence
    ///   wins; mode identity is the name, so a second entry
    ///   would be unreachable and could shadow-edit the first);
    /// - strips an icon from the default mode (its menu bar
    ///   icon is fixed; this replaces #15's debug-only writer
    ///   assert with unconditional normalization).
    private static func sanitized(
        _ modes: [KeyMode]
    ) -> [KeyMode] {
        var seen: Set<String> = []
        var result: [KeyMode] = []
        for var mode in modes {
            guard !mode.name.isEmpty else { continue }
            guard seen.insert(mode.name).inserted else {
                continue
            }
            if mode.isDefault { mode.icon = nil }
            result.append(mode)
        }
        return result
    }
}
