import Foundation

/// Which paths are the bar subsystem — read off
/// `.claude/rules/bars.md`'s own `paths:` front matter rather
/// than listed here (#1078).
///
/// That front matter is what Claude Code loads the bar rules on,
/// so it is already the answer to "is this bar code?", and it
/// names six paths rather than one: bar logic lands in an
/// `App/KiwiCore+*Bar*.swift` driver as readily as under `Bar/`,
/// which is the case #1214 shipped wrong twice. A guard that
/// hand-listed the directory instead would scan a subset while
/// its own floor stayed green — the `ChromeScanRoots` argument
/// one directory over, except that here the register already
/// exists and copying it is the only mistake available.
///
/// So the derivation is the point: a path added to bars.md joins
/// every guard built on this in the same edit, and a front
/// matter that stops parsing empties the list, which each
/// consumer floors against.
///
/// **A floor is not enough, and this is why `expected` exists.**
/// A fence that stops parsing empties the list and reds every
/// floor; a front matter that parses and simply says LESS reds
/// nothing — guard-prover left a live ungated
/// `NSAnimationContext` in `KiwiCore+SpaceBar.swift`, deleted
/// that one line from bars.md, and the whole suite went green
/// with 51 files still scanned. Worse than a plain coverage
/// hole: bars.md is also what routes a HUMAN to the rule, so the
/// edit that un-guards the file is the same edit that stops
/// telling anyone the rule applies to it. `expected` answers
/// from the TREE instead, so the declared list has to keep up
/// with the files rather than the other way round.
enum BarScanRoots {
    /// The paths the subsystem must reach, read off the file
    /// system: the bar directory, and every `App/` file whose
    /// own name says it is bar code. A path here that bars.md
    /// does not declare reds `coversTheSubsystem`.
    static func expected(from filePath: String) -> [String] {
        let repo = SourceScan.repoRoot(from: filePath)
        let app = "Sources/KiwiDeskCore/App"
        let named =
            (try? FileManager.default.contentsOfDirectory(
                atPath: repo.appendingPathComponent(app).path
            )) ?? []
        return ["Sources/KiwiDeskCore/Bar"]
            + named
            .filter {
                $0.hasSuffix(".swift") && $0.contains("Bar")
            }
            .map { "\(app)/\($0)" }
            .sorted()
    }

    /// The declared paths, `/**` stripped, as absolute URLs.
    static func paths(from filePath: String) -> [URL] {
        let repo = SourceScan.repoRoot(from: filePath)
        let rules =
            repo
            .appendingPathComponent(".claude/rules/bars.md")
        guard let text = try? String(contentsOf: rules, encoding: .utf8),
            let matter = frontMatter(of: text)
        else { return [] }
        return matter.compactMap(declared).map {
            repo.appendingPathComponent($0)
        }
    }

    /// Every Swift file the declared paths reach — a directory
    /// enumerated, a named file taken as itself.
    static func sources(from filePath: String) throws -> [URL] {
        var files: [URL] = []
        for path in paths(from: filePath) {
            var isDirectory: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: path.path,
                    isDirectory: &isDirectory
                )
            else { continue }
            if isDirectory.boolValue {
                files += try SourceScan.swiftSources(under: path)
            } else {
                files.append(path)
            }
        }
        return files
    }

    /// The lines between the opening and closing `---`.
    private static func frontMatter(of text: String) -> [String]? {
        let lines = text.components(separatedBy: "\n")
        guard lines.first == "---",
            let end = lines.dropFirst().firstIndex(of: "---")
        else { return nil }
        return Array(lines[1..<end])
    }

    /// A `  - "path"` entry, with any trailing `/**` removed. A
    /// comment line in the block is skipped by the shape rather
    /// than by a `#` test: bars.md's own comments are why the
    /// list needs parsing at all.
    private static func declared(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(
            in: .whitespaces
        )
        guard trimmed.hasPrefix("- \""), trimmed.hasSuffix("\"")
        else { return nil }
        let path =
            trimmed
            .dropFirst(3)
            .dropLast()
            .trimmingCharacters(in: .whitespaces)
        guard path.hasPrefix("Sources/") else { return nil }
        return path.hasSuffix("/**")
            ? String(path.dropLast(3)) : path
    }
}
