import Foundation

/// The format-stamp half of the crossing (#938), and the one
/// step that changes a file's SHAPE rather than a value
/// (#939) - split from `ConfigMigration.swift` for file
/// size (AGENTS.md 2.1).
extension ConfigMigration {
    /// Lifts a legacy bare array of color palettes into the wrapped
    /// document format `{"format": 1, "palettes": [...]}` (#939).
    ///
    /// ASSUMES any top-level JSON array is a legacy palettes
    /// file — true only because palettes.json is the sole
    /// array-rooted file among the routed readers
    /// (`ConfigMigrationRoutingTests` is the census; a second
    /// array-rooted shape must give this step a narrower gate
    /// on arrival). An array handed to `readBackup` gets
    /// wrapped and then refused as not-a-bundle — harmless, but
    /// the assumption is this sentence, not a law.
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

    /// Stamps the target format into `data` if not already
    /// current (#938).
    ///
    /// Shares the envelope with the two rewriting steps
    /// (`surgicallyApplying`) but differs at the edges in one
    /// way worth naming: it returns `Data`, never nil, because a
    /// caller stamps unconditionally and wants the bytes back
    /// either way. "Nothing changed" therefore reads as
    /// `?? data` here rather than as a nil the caller inspects.
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
