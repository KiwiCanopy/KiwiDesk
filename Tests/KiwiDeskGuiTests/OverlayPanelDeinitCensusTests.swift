import Foundation
import Testing

/// Every Core class that stores a panel orders it out in its own
/// `isolated deinit` (#1868, core-boundaries.md). A struct
/// holding one is a value, so the class it lives in answers.
/// "A panel" is `NSPanel`, `NSWindow` or a Core subclass of
/// either, stored directly, in a collection, or initialized in
/// place — by a constructor or a Core function returning one; a
/// local inside a function is not stored, and a store at file
/// scope, owned by no class, is refused. The deinit must name
/// each stored panel beside its `orderOut(` — by property name,
/// so a struct's panel is named through its holder's loop. A type
/// followed by `.` is a member of it (`NSWindow.Level`), not a
/// panel; the trade is any `NSPanel.Something` store, which by
/// that spelling holds no window.
/// `OverlayPanelReleaseTests` proves the behaviour for the shelf
/// and the sticky mark; this census holds the class.
@Suite("Overlay panel deinit census (#1868)")
struct OverlayPanelDeinitCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let typeKeywords: Set<String> = [
        "class", "struct", "enum", "actor", "extension",
    ]
    private static let scopeKeyword = try! NSRegularExpression(
        pattern: #"\b(class|struct|enum|actor|extension|protocol|"#
            + #"func|init|deinit|var|let|if|guard|for|while|"#
            + #"switch|else|do|catch|get|set|willSet|didSet|"#
            + #"defer|repeat)\b\s*(\w*)"#
    )

    private struct Scope {
        let keyword: String
        let name: String
        let open: Int
        let parent: Int?
    }

    private struct Parse {
        var scopes: [Scope] = []
        /// Scope index → the index one past its closing brace.
        var close: [Int: Int] = [:]
        /// Offset → the innermost scope open there.
        var innermost: [Int: Int] = [:]
    }

    private func sources() throws -> [(String, String)] {
        try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        ).map {
            (
                $0.lastPathComponent,
                SourceScan.blankingCommentsAndLiterals(
                    try SourceScan.rawSource(at: $0)
                )
            )
        }
    }

    /// `NSPanel`, `NSWindow`, and every Core class descending
    /// from either — derived, so a new subclass is a panel too.
    private func panelTypes(in files: [(String, String)]) -> [String] {
        var types: Set<String> = ["NSPanel", "NSWindow"]
        var grew = true
        while grew {
            grew = false
            for (_, text) in files {
                for name in matches(
                    #"\bclass\s+(\w+)\s*:\s*(\w+)"#,
                    in: text
                )
                where types.contains(name.1)
                    && !types.contains(
                        name.0
                    )
                {
                    types.insert(name.0)
                    grew = true
                }
            }
        }
        return types.sorted()
    }

    /// Every Core function that returns a panel type, so a store
    /// initialized through one (`lazy var panel = makePanel()`)
    /// is a store too.
    private func panelFactories(
        returning alternatives: String,
        in files: [(String, String)]
    ) -> [String] {
        var names: Set<String> = []
        for (_, text) in files {
            for hit in matches(
                #"\bfunc\s+(\w+)\s*\([^)]*\)\s*->\s*("#
                    + alternatives + #")(?![.\w?])"#,
                in: text
            ) {
                names.insert(hit.0)
            }
        }
        return names.sorted()
    }

    private func matches(
        _ pattern: String,
        in text: String
    ) -> [(String, String)] {
        let regex = try! NSRegularExpression(pattern: pattern)
        let ns = text as NSString
        return regex.matches(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        ).map {
            (
                ns.substring(with: $0.range(at: 1)),
                ns.substring(with: $0.range(at: 2))
            )
        }
    }

    /// Every brace scope of `text`, named by the last declaration
    /// keyword before its `{`.
    private func parse(_ text: NSString) -> Parse {
        var result = Parse()
        var stack: [Int] = []
        var segmentStart = 0
        for i in 0..<text.length {
            let unit = text.character(at: i)
            if let top = stack.last { result.innermost[i] = top }
            if unit == 123 {  // {
                let range = NSRange(
                    location: segmentStart,
                    length: i - segmentStart
                )
                let hit = Self.scopeKeyword.matches(
                    in: text as String,
                    range: range
                ).last
                result.scopes.append(
                    Scope(
                        keyword: hit.map {
                            text.substring(with: $0.range(at: 1))
                        } ?? "",
                        name: hit.map {
                            text.substring(with: $0.range(at: 2))
                        } ?? "",
                        open: i,
                        parent: stack.last
                    )
                )
                stack.append(result.scopes.count - 1)
                segmentStart = i + 1
            } else if unit == 125 {  // }
                if let top = stack.popLast() { result.close[top] = i }
                segmentStart = i + 1
            } else if unit == 59 {  // ;
                segmentStart = i + 1
            }
        }
        return result
    }

    /// The class (or actor) that owns scope `index`: itself, or
    /// the nearest enclosing one past any struct or enum.
    private func owningClass(_ index: Int, in parse: Parse) -> Int? {
        var cursor: Int? = index
        while let current = cursor {
            let keyword = parse.scopes[current].keyword
            if keyword == "class" || keyword == "actor" { return current }
            cursor = parse.scopes[current].parent
        }
        return nil
    }

    @Test("every class storing a panel orders it out in its deinit")
    func everyOwnerReleases() throws {
        let files = try sources()
        let types = panelTypes(in: files)
        let alternatives = types.joined(separator: "|")
        let makers = panelFactories(returning: alternatives, in: files)
        let stored = try NSRegularExpression(
            pattern: #"\b(?:var|let)\s+(\w+)\s*(?::\s*\[?\s*"#
                + #"(?:\w+\s*:\s*)?(?:"# + alternatives
                + #")(?![.\w])\s*\]?\??|=\s*(?:\w+\.)?(?:"#
                + (types + makers).joined(separator: "|") + #")\()"#
        )
        var owners: Set<String> = []
        var offenders: [String] = []
        for (file, text) in files {
            let ns = text as NSString
            let hits = stored.matches(
                in: text,
                range: NSRange(location: 0, length: ns.length)
            )
            guard !hits.isEmpty else { continue }
            let tree = parse(ns)
            for hit in hits {
                let property = ns.substring(with: hit.range(at: 1))
                guard let scope = tree.innermost[hit.range.location]
                else {
                    offenders.append("\(file): \(property) at file scope")
                    continue
                }
                // A local inside a function is not a stored property.
                guard Self.typeKeywords.contains(tree.scopes[scope].keyword)
                else { continue }
                guard let owner = owningClass(scope, in: tree) else {
                    offenders.append("\(file): no class owns it")
                    continue
                }
                let name = tree.scopes[owner].name
                owners.insert(name)
                let releases = tree.scopes.indices.contains {
                    let deinitScope = tree.scopes[$0]
                    guard deinitScope.keyword == "deinit",
                        deinitScope.parent == owner,
                        let end = tree.close[$0]
                    else { return false }
                    let head = ns.substring(
                        with: NSRange(
                            location: max(0, deinitScope.open - 40),
                            length: min(40, deinitScope.open)
                        )
                    )
                    let body = ns.substring(
                        with: NSRange(
                            location: deinitScope.open,
                            length: end - deinitScope.open
                        )
                    )
                    return head.contains("isolated deinit")
                        && body.contains("orderOut(")
                        && body.contains(property)
                }
                if !releases {
                    offenders.append("\(file): \(name).\(property)")
                }
            }
        }
        // The derivation and the scan still see what they were
        // written for.
        #expect(types.contains("BorderOverlayPanel"))
        for expected in [
            "ShelfOverlay", "StickyMarkOverlay", "SizeLimitOverlay",
            "Marker", "MonocleFlipOverlay", "AppKitBorderOverlay",
        ] {
            #expect(
                owners.contains(expected),
                .init(rawValue: "\(expected) unseen")
            )
        }
        #expect(
            offenders.isEmpty,
            .init(rawValue: "no ordering-out deinit: \(offenders)")
        )
    }
}
