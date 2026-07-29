import Foundation

/// One place a needle matched in a scanned tree.
struct MachineTouchSite {
    let file: URL
    /// 1-based, so it reads like a compiler diagnostic.
    let line: Int

    var site: String { "\(file.lastPathComponent):\(line)" }
}

extension SourceScan {
    /// Every occurrence of `needle` under `directory`, comments
    /// stripped, where the character before the match is not an
    /// identifier character — so `KiwiCore(` matches neither
    /// `makeTestCore(` nor a hypothetical `MockKiwiCore(`.
    ///
    /// Backs `MachineTouchTests`: the machine-touch guards pin
    /// *construction sites* (a type name followed by `(`), and a
    /// plain substring count would let a wrapper type or factory
    /// suffix silently satisfy or evade the pin.
    ///
    /// `stripComments`' known `//`-inside-a-string cut was
    /// weighed for these needles (per `SourceScan.swift`): for a
    /// stray-detector it fails OPEN — a violation after such a
    /// string on one line is erased — but a construction site
    /// sharing its line with a `//`-bearing literal has no
    /// plausible shape under the 79-char format, and each
    /// guard's presence canary reds if the scan goes blind
    /// wholesale.
    static func identifierSites(
        of needle: String,
        under directory: URL
    ) throws -> [MachineTouchSite] {
        var found: [MachineTouchSite] = []
        for file in try swiftSources(under: directory) {
            let lines = stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            for index in lines.indices {
                let line = lines[index]
                var cursor = line.startIndex
                while let hit = line.range(
                    of: needle,
                    range: cursor..<line.endIndex
                ) {
                    defer { cursor = hit.upperBound }
                    if hit.lowerBound > line.startIndex {
                        let before = line[
                            line.index(
                                before: hit.lowerBound
                            )
                        ]
                        if before.isLetter || before.isNumber
                            || before == "_"
                        {
                            continue
                        }
                    }
                    found.append(
                        MachineTouchSite(
                            file: file,
                            line: index + 1
                        )
                    )
                }
            }
        }
        return found
    }

    /// The whole of `file`, comments stripped, every line
    /// whitespace-trimmed, blank lines dropped — the form the
    /// twin files are compared by. Whole-file, not per-function:
    /// a hand-picked function list is itself one more place to
    /// forget (a neutralization added as a *new* symbol in one
    /// twin only would slip a narrower net), and the twins'
    /// non-code differences are doc comments, which strip away.
    static func normalizedFile(
        _ file: URL
    ) throws -> String {
        stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(
            separator: "\n",
            omittingEmptySubsequences: true
        )
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    /// The type names declared under an `@Suite` attribute in
    /// `file`: for each stripped line starting with `@Suite`,
    /// the identifier after the next `struct `/`class ` keyword.
    /// Backs the partition guard's *type* axis — `swift test
    /// --skip/--filter` matches test identifiers, so the suite
    /// TYPE name is what the partition actually consumes; the
    /// filename is only the greppable convention.
    static func suiteTypeNames(
        in file: URL
    ) throws -> [String] {
        let lines = stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(separator: "\n", omittingEmptySubsequences: false)
        var names: [String] = []
        var pending = false
        for line in lines {
            let bare = line.trimmingCharacters(in: .whitespaces)
            if bare.hasPrefix("@Suite") { pending = true }
            guard pending else { continue }
            for keyword in ["struct ", "class "] {
                guard let range = bare.range(of: keyword)
                else { continue }
                let name = bare[range.upperBound...].prefix {
                    $0.isLetter || $0.isNumber || $0 == "_"
                }
                if !name.isEmpty {
                    names.append(String(name))
                    pending = false
                }
            }
        }
        return names
    }
}
