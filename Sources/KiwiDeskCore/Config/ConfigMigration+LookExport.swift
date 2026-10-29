import Foundation

/// The exported look file crosses in MEMORY (#1740): it is never
/// rewritten, so no stamp ends its crossing, as the palette
/// sidecar's shelving (profiles.md). Each entry lifts a file below
/// `to` with the step that renamed a look path at that format; a
/// `LookDocument.currentFormat` bump owes an entry lifting to it
/// (`LookExportStepsCensusTests`).
extension ConfigMigration {
    static let lookExportSteps: [(to: Int, step: @Sendable (Data) -> Data?)] =
        [
            (to: 2, step: migratingShelfGlideOntoExpand)
        ]

    /// `data`, written at `format`, with every step above it applied.
    static func crossingLookExport(_ data: Data, from format: Int) -> Data {
        var bytes = data
        for entry in lookExportSteps where format < entry.to {
            bytes = entry.step(bytes) ?? bytes
        }
        return bytes
    }
}
