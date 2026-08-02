import Foundation

/// Decode-time normalization for untrusted layer lists (#31).
///
/// `[KeyLayer]` enters from hand-editable JSON at exactly two
/// sites — `GuiConfig.layers` (the `gui.json` sidecar) and
/// `KeyLayerOverride` (a profile's sparse `"layers"` override).
/// A hand-edited file can carry duplicate layer names, an icon
/// on the default layer, or empty names; every GUI entry point
/// blocks these, so decode is the one untrusted boundary.
///
/// Both `init(from:)` contexts are pure `Codable` — the
/// config-issue reporter is unreachable from there — so invalid
/// input is normalized silently and predictably instead of
/// rejected. Re-saving persists the normalized form; that is
/// the migration (AGENTS.md §5, pre-release). ONE shared helper
/// serves both sites so the rules cannot drift apart.
extension KeyLayer {
    /// Normalizes a FULL layer list (`GuiConfig.layers`):
    /// `sanitized`, plus the always-present default layer is
    /// guaranteed to exist and sit first (the documented list
    /// convention; the GUI and the structured loader assume a
    /// default layer is available). Empty input therefore falls
    /// back to `[KeyLayer.defaultLayer]` — the pre-#31 behavior.
    public static func normalized(
        full layers: [KeyLayer]
    ) -> [KeyLayer] {
        var result = sanitized(layers)
        if let at = result.firstIndex(where: { $0.isDefault }) {
            if at != 0 {
                result.insert(result.remove(at: at), at: 0)
            }
        } else {
            result.insert(.defaultLayer, at: 0)
        }
        return result
    }

    /// Normalizes a SPARSE override list (`KeyLayerOverride`):
    /// `sanitized` only. A sparse list must NEVER gain a
    /// default entry — a missing layer means "inherit the base"
    /// (O4 soft), and order is preserved as stored.
    public static func normalized(
        sparse layers: [KeyLayer]
    ) -> [KeyLayer] {
        sanitized(layers)
    }

    /// The shared core, applied by both flavors:
    /// - drops layers with an empty or whitespace-only name
    ///   (never addressable — the GUI trims names and cannot
    ///   create, select, or delete blank ones);
    /// - drops later duplicates of a name (FIRST occurrence
    ///   wins; layer identity is the name, so a second entry
    ///   would be unreachable and could shadow-edit the first.
    ///   Deliberately unlike combos WITHIN a layer, which are
    ///   last-wins at registration — see StructuredConfig);
    /// - strips an icon from the default layer (its menu bar
    ///   icon is fixed; this succeeds the #28 debug-only
    ///   writer assert, gone with the generated-init.lua
    ///   writer in #55, as unconditional normalization).
    private static func sanitized(
        _ layers: [KeyLayer]
    ) -> [KeyLayer] {
        var seen: Set<String> = []
        var result: [KeyLayer] = []
        for var layer in layers {
            let name = layer.name.trimmingCharacters(
                in: .whitespaces
            )
            guard !name.isEmpty else { continue }
            guard seen.insert(layer.name).inserted else {
                continue
            }
            if layer.isDefault { layer.icon = nil }
            result.append(layer)
        }
        return result
    }
}
