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
enum BarScanRoots {
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
