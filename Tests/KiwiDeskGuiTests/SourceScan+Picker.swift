import Foundation

/// `SegmentedPicker`'s source as the guards that read it see it
/// (#1229): the base file and every `SegmentedPicker+*.swift`
/// extension, comments stripped, joined. One copy of which files
/// make up the picker, so an extension split out later is scanned
/// by every guard at once rather than falling outside one.
extension SourceScan {
    struct NoPickerParts: Error {}

    static func segmentedPickerSource(
        from filePath: String
    ) throws -> String {
        let folder = repoRoot(from: filePath).appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/Common"
        )
        let names = try FileManager.default
            .contentsOfDirectory(atPath: folder.path)
            .filter {
                $0.hasPrefix("SegmentedPicker+") && $0.hasSuffix(".swift")
            }
            .sorted()
        // The floor: a split the walk cannot find reads as no split.
        guard !names.isEmpty else { throw NoPickerParts() }
        return try (["SegmentedPicker.swift"] + names).map {
            try strippedSource(at: folder.appendingPathComponent($0))
        }.joined(separator: "\n")
    }
}
