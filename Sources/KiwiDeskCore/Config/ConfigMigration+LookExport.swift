import Foundation

/// The exported look file crosses in MEMORY (#1740): a markerless
/// sidecar has no stamp to end on and is never rewritten, as the
/// palette sidecar's shelving (profiles.md). A step that renames a
/// look path or a value a look stores joins `lookExportSteps`
/// beside its `steps` entry, or an older file loses that styling on
/// import (`LookExportFormatTests` ▸ `olderFileCrosses`).
extension ConfigMigration {
    static let lookExportSteps: [@Sendable (Data) -> Data?] = [
        migratingShelfGlideOntoExpand
    ]

    /// `data` with every look-path step applied, unchanged where
    /// none rewrites it.
    static func crossingLookExport(_ data: Data) -> Data {
        lookExportSteps.reduce(data) { bytes, step in
            step(bytes) ?? bytes
        }
    }
}
