import Foundation

/// One `var onLog:` declaration found in source.
struct LogSeamDeclaration {
    let file: URL
    /// 1-based, so it reads like a compiler diagnostic.
    let line: Int
    /// The enclosing type, or nil when the walk could not resolve
    /// one — a gap for the consumer to red on, never a silent skip.
    let owner: String?
    /// The trimmed text right of the first `=` on the declaration
    /// line, or nil when the line carries none.
    let defaultValue: String?

    var site: String { "\(file.lastPathComponent):\(line)" }
}

extension SourceScan {
    /// Every `var onLog:` declaration under `directory`, with the
    /// type that encloses it and the default it carries.
    ///
    /// **One walk, two guards.** `LogSeamWiringTests` reads the
    /// owners, `LogSeamDefaultTests` reads the defaults, and both
    /// used to carry their own copy of this needle plus their own
    /// copy of the reason the colon is in it. That is the drift
    /// `tests.md` names for this helper family: teach one copy to
    /// read a shape the other cannot — a wrapped declaration, a
    /// `let` seam, two spaces after `var` — and the two guards
    /// silently disagree about which seams exist, so the narrower
    /// one stops covering a seam the other still does, with both
    /// green.
    ///
    /// The colon is load-bearing: without it a future
    /// `onLogLevel` registers as a seam, and is then asked both
    /// for a wiring and for a default it has no use for.
    static func logSeamDeclarations(
        under directory: URL
    ) throws -> [LogSeamDeclaration] {
        var found: [LogSeamDeclaration] = []
        for file in try swiftSources(under: directory) {
            let lines = try strippedSource(at: file)
                .split(
                    separator: "\n",
                    omittingEmptySubsequences: false
                )
            let enclosing = enclosingTypes(of: lines)
            for index in lines.indices
            where lines[index].contains("var onLog:") {
                found.append(
                    LogSeamDeclaration(
                        file: file,
                        line: index + 1,
                        owner: enclosing[index],
                        defaultValue: defaultValue(
                            on: lines[index]
                        )
                    )
                )
            }
        }
        return found
    }

    /// The trimmed text after the first `=`, or nil when the line
    /// carries none. A seam's type — `@MainActor (String) -> Void`
    /// — holds no `=`, so the first one is the assignment's.
    private static func defaultValue(
        on line: Substring
    ) -> String? {
        guard let equals = line.firstIndex(of: "=") else {
            return nil
        }
        let value = line[line.index(after: equals)...]
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
