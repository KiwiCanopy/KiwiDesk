import Foundation

/// Format stamping and document structure migrations
/// (`ConfigMigrationRoutingTests`, #938, #939).
extension ConfigMigration {
    /// Wraps legacy palette array into format document
    /// (`PaletteDocument`, #939). ASSUMES any top-level JSON array
    /// is a legacy palettes file — true only while palettes.json
    /// is the sole array-rooted routed reader
    /// (`ConfigMigrationRoutingTests`); a second array-rooted
    /// shape must give this step a narrower gate.
    @Sendable
    static func migratingLegacyPalettesArray(
        _ data: Data
    ) -> Data? {
        guard
            let array = try? JSONSerialization.jsonObject(
                with: data
            ) as? [Any]
        else { return nil }
        let wrapped: [String: Any] = [
            "format": PaletteDocument.currentFormat,
            "palettes": array,
        ]
        return try? JSONSerialization.data(
            withJSONObject: wrapped,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Stamps target format integer into JSON document payload (#938).
    static func stamped(_ data: Data) -> Data {
        guard
            let root = try? JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
        else { return data }
        let target = targetFormat(for: root)
        return surgicallyApplying(
            data,
            rewriting: { node in
                guard var dict = node as? [String: Any] else {
                    return (node, false)
                }
                if dict["format"] as? Int == target {
                    return (node, false)
                }
                dict["format"] = target
                return (dict, true)
            },
            editing: { surgicallyStamped($0, format: target) }
        ) ?? data
    }

    /// Surgically inserts or updates the `"format"` key in `text`.
    private static func surgicallyStamped(
        _ text: String,
        format: Int
    ) -> Data? {
        if text.range(
            of: "\"format\"\\s*:",
            options: .regularExpression
        ) != nil {
            let replaced = text.replacingOccurrences(
                of: "(\"format\"\\s*:\\s*)\\d+",
                with: "$1\(format)",
                options: .regularExpression
            )
            return replaced.data(using: .utf8)
        }
        guard let brace = text.range(of: "{") else { return nil }
        var out = text
        let after = text[brace.upperBound...]
        if after.hasPrefix("\r\n") || after.hasPrefix("\n") {
            out.insert(
                contentsOf: "\n  \"format\" : \(format),",
                at: brace.upperBound
            )
        } else {
            out.insert(
                contentsOf: "\"format\":\(format),",
                at: brace.upperBound
            )
        }
        return out.data(using: .utf8)
    }
}
