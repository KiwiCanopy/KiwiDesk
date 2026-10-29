import Foundation
import Testing

@testable import KiwiDeskCore

/// No `ConfigMigration` floor sits past its shape's
/// `currentFormat`: that is a dropped bump, since `needsMigration`
/// then lets no file at the shipped format through and the step
/// never reaches the files it exists to rescue (#1020). A backstop
/// for one spelling of that defect only — a floor EQUAL to an
/// un-bumped format is just as dead and passes here, which is why
/// profiles.md owes every step a test through `migrated`.
///
/// Reads the `static let` floors of `ConfigMigration+*.swift` and
/// the `MachineConfig.moves` table. A floor's shape is its name's
/// suffix, so a floor misnamed for another shape is checked
/// against that shape's format and can pass while its own bump is
/// missing.
@Suite("Config migration floor census")
struct ConfigMigrationFloorCensusTests {
    private struct Floor {
        let file: String
        let name: String
        let value: Int?
    }

    /// Below this the scan is reading nothing and every floor
    /// clause passes vacuously; removing an old step (#902) lowers
    /// it on purpose.
    private let minimumFloors = 24

    private let shapes: [(suffix: String, current: Int)] = [
        ("BundleFormat", SetupBundle.currentFormat),
        ("GuiFormat", GuiConfig.currentFormat),
        ("PaletteFormat", PaletteDocument.currentFormat),
        ("ProfileFormat", Profile.currentFormat),
    ]

    /// Every `static let|var …Format` declaration; `value` is nil
    /// when it is not a bare integer literal, which the census
    /// refuses rather than skips.
    private func floors() throws -> [Floor] {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Config")
        let files = try FileManager.default
            .contentsOfDirectory(atPath: dir.path)
            .filter {
                $0.hasPrefix("ConfigMigration+") && $0.hasSuffix(".swift")
            }
        let declaration = try Regex(
            #"static (?:let|var) (\w+Format)\b([^\n]*)"#
        )
        let literal = try Regex(#"^\s*(?::\s*Int\s*)?=\s*(\d+)\s*$"#)
        return try files.sorted().flatMap { file in
            let source = try SourceScan.strippedSource(
                at: dir.appendingPathComponent(file)
            )
            return source.matches(of: declaration).compactMap {
                match -> Floor? in
                guard let name = match.output[1].substring
                else { return nil }
                let rest = match.output[2].substring ?? ""
                let digits = rest.wholeMatch(of: literal)?
                    .output[1].substring
                return Floor(
                    file: file,
                    name: String(name),
                    value: digits.flatMap { Int($0) }
                )
            }
        }
    }

    private func current(for name: String) -> Int? {
        shapes.first { name.hasSuffix($0.suffix) }?.current
    }

    @Test("no step floor sits past its shape's current format")
    func floorsWithinCurrentFormats() throws {
        let found = try floors()
        #expect(found.count >= minimumFloors, "\(found.count) floors")
        for floor in found {
            let value = try #require(
                floor.value,
                "\(floor.file): \(floor.name) is not an integer literal"
            )
            let current = try #require(
                current(for: floor.name),
                "\(floor.file): \(floor.name) ends in no shape suffix"
            )
            #expect(
                value <= current,
                """
                \(floor.file): \(floor.name) = \(value) is past \
                current format \(current); bump the shape's \
                currentFormat
                """
            )
        }
    }

    @Test("no machine-leaf move sits past the formats it strips at")
    func movesWithinCurrentFormats() {
        #expect(!MachineConfig.moves.isEmpty)
        for move in MachineConfig.moves {
            #expect(
                move.guiFormat <= GuiConfig.currentFormat,
                "\(move.keys): gui \(move.guiFormat)"
            )
            #expect(
                move.bundleFormat <= SetupBundle.currentFormat,
                "\(move.keys): bundle \(move.bundleFormat)"
            )
        }
    }
}
