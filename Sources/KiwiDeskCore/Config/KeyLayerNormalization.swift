import Foundation

/// Decode-time normalization for key layer configurations
/// (`GuiConfig.layers`, #31).
extension KeyLayer {
    /// Normalizes full layer list ensuring default layer sits first
    /// (`GuiConfig.layers`, AGENTS.md §5, #31).
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

    /// Normalizes sparse override list without adding default layer
    /// (`KeyLayerOverride`).
    public static func normalized(
        sparse layers: [KeyLayer]
    ) -> [KeyLayer] {
        sanitized(layers)
    }

    /// Sanitizes layer names, deduplicates, and strips icons from default
    /// layer (#28, #55).
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
