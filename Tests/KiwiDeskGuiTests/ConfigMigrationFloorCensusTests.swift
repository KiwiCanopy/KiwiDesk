import Foundation
import Testing

@testable import KiwiDeskCore

/// Every format floor a `ConfigMigration` step declares sits at or
/// below its shape's `currentFormat`. A floor past it means the
/// bump was dropped: `needsMigration` lets no file at the shipped
/// format through, so the step never reaches the files it exists
/// to rescue (#1020).
///
/// A floor's shape is the last of Bundle, Gui, Palette or Profile
/// in its name. Known limit: a step gated by no named floor is
/// invisible here and still owes its own test through `migrated`
/// (profiles.md).
@Suite("Config migration floor census")
struct ConfigMigrationFloorCensusTests {
    private struct Floor {
        let file: String
        let name: String
        let value: Int
    }

    /// The step floors on `main` when this census landed; the
    /// count only grows as steps arrive.
    private let minimumFloors = 24

    private let shapes: [(token: String, current: Int)] = [
        ("bundle", SetupBundle.currentFormat),
        ("gui", GuiConfig.currentFormat),
        ("palette", PaletteDocument.currentFormat),
        ("profile", Profile.currentFormat),
    ]

    private func floors() throws -> [Floor] {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Config")
        let files = try FileManager.default
            .contentsOfDirectory(atPath: dir.path)
            .filter {
                $0.hasPrefix("ConfigMigration+") && $0.hasSuffix(".swift")
            }
        let pattern = try Regex(#"static let (\w+Format) = (\d+)"#)
        return try files.sorted().flatMap { file in
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: dir.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            return source.matches(of: pattern).compactMap {
                match -> Floor? in
                guard
                    let name = match.output[1].substring,
                    let digits = match.output[2].substring,
                    let value = Int(digits)
                else { return nil }
                return Floor(file: file, name: String(name), value: value)
            }
        }
    }

    /// The shape token occurring last in `name`, so
    /// `profileIDBundleFormat` is a bundle floor.
    private func current(for name: String) -> Int? {
        let lower = name.lowercased()
        return
            shapes
            .compactMap { shape in
                lower.range(of: shape.token, options: .backwards).map {
                    (at: $0.lowerBound, current: shape.current)
                }
            }
            .max { $0.at < $1.at }?
            .current
    }

    @Test("no step floor sits past its shape's current format")
    func floorsWithinCurrentFormats() throws {
        let found = try floors()
        #expect(found.count >= minimumFloors, "\(found.count) floors")
        for floor in found {
            let current = try #require(
                current(for: floor.name),
                "\(floor.file): \(floor.name) names no shape"
            )
            #expect(
                floor.value <= current,
                """
                \(floor.file): \(floor.name) = \(floor.value) is past \
                current format \(current); bump the shape's \
                currentFormat
                """
            )
        }
    }
}
