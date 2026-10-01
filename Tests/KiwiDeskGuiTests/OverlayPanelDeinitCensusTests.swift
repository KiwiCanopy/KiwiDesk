import Foundation
import Testing

/// Every Core class that stores a panel orders it out in its own
/// `isolated deinit` (#1868, core-boundaries.md). A struct
/// holding one is a value, so the class it lives in answers.
/// "A panel" is `NSPanel`, `NSWindow` or a Core subclass of
/// either, stored directly, in a collection, or initialized in
/// place — by a constructor or a Core function returning one; a
/// local inside a function is not stored, and a store at file
/// scope, or in a struct no class lexically encloses, is
/// refused. The deinit must name each stored panel as a whole
/// identifier beside its `orderOut(`, so a struct's panel is
/// named through its holder's loop. The scope walk is
/// `SourceScan.scopeTree`'s, held by `SourceScanScopesTests`. A type
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
            let tree = SourceScan.scopeTree(of: ns)
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
                guard let owner = tree.owningClass(of: scope) else {
                    offenders.append("\(file): no class owns it")
                    continue
                }
                let name = tree.scopes[owner].name
                owners.insert(name)
                let releases = tree.scopes.indices.contains {
                    let deinitScope = tree.scopes[$0]
                    guard deinitScope.keyword == "deinit",
                        deinitScope.parent == owner,
                        let body = tree.body($0, in: ns)
                    else { return false }
                    let head = ns.substring(
                        with: NSRange(
                            location: max(0, deinitScope.open - 40),
                            length: min(40, deinitScope.open)
                        )
                    )
                    return head.contains("isolated deinit")
                        && body.contains("orderOut(")
                        && SourceScan.mentions(
                            identifier: property,
                            in: body
                        )
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
