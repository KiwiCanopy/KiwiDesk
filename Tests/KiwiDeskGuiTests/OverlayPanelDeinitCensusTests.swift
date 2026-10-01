import Foundation
import Testing

/// Every Core class that stores a panel orders it out in its own
/// `isolated deinit` (#1868, core-boundaries.md). A struct
/// holding one is a value, so the class it lives in answers.
/// "A panel" is `NSPanel`, `NSWindow`, a Core subclass or alias
/// of either, or a Core function returning one, named anywhere in
/// a stored property's declaration line — its type, however
/// nested, or its initializer; a function-typed store takes a
/// panel rather than holding one and is not counted; a
/// local inside a function is not stored, and a store at file
/// scope, or in a struct no class lexically encloses, is
/// refused. The deinit must name each stored panel as a whole
/// identifier beside its `orderOut(`, so a struct's panel is
/// named through its holder's loop. The scope walk is
/// `SourceScan.scopeTree`'s, held by `SourceScanScopesTests`.
/// The net's reach, stated: a declaration whose type wraps onto
/// the next line, the second name of `var a, b: NSPanel?`, and a
/// window held through an `NSWindowController` (which owns its
/// teardown) are not seen. A type
/// followed by `.` is a member of it (`NSWindow.Level`), not a
/// panel; the trade is any `NSPanel.Something` store, which by
/// that spelling holds no window.
/// `OverlayPanelReleaseTests` proves the behaviour for the shelf
/// and the sticky mark; this census holds the class.
@Suite("Overlay panel deinit census (#1868)")
struct OverlayPanelDeinitCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

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
    /// from either or alias naming one — derived, so a new
    /// subclass (generic or module-qualified) or a `typealias`
    /// is a panel too.
    private func panelTypes(in files: [(String, String)]) -> [String] {
        var types: Set<String> = ["NSPanel", "NSWindow"]
        let shapes = [
            #"\bclass\s+(\w+)(?:<[^>]*>)?\s*:\s*(?:\w+\.)?(\w+)"#,
            #"\btypealias\s+(\w+)\s*=\s*(?:\w+\.)?(\w+)"#,
        ]
        var grew = true
        while grew {
            grew = false
            for (_, text) in files {
                for shape in shapes {
                    for (name, base) in matches(shape, in: text)
                    where types.contains(base) && !types.contains(name) {
                        types.insert(name)
                        grew = true
                    }
                }
            }
        }
        return types.sorted()
    }

    /// Every Core function that returns a panel type, optional or
    /// not, as the call spellings that reach it: bare or through
    /// `Self.` / `self.` inside its type, or `<DeclaringType>.`
    /// outside it — so a store made through one (`lazy var panel =
    /// makePanel()`) is a store too, and another type's
    /// same-named `make()` is not.
    private func panelFactoryCalls(
        returning alternatives: String,
        in files: [(String, String)]
    ) -> [String] {
        let factory = try! NSRegularExpression(
            pattern: #"\bfunc\s+(\w+)[^{]*?->\s*(?:\w+\.)?(?:"#
                + alternatives + #")\b(?!\.)"#
        )
        var calls: Set<String> = []
        for (_, text) in files {
            let ns = text as NSString
            let tree = SourceScan.scopeTree(of: ns)
            for hit in factory.matches(
                in: text,
                range: NSRange(location: 0, length: ns.length)
            ) {
                let name = ns.substring(with: hit.range(at: 1))
                let owner = tree.enclosingType(at: hit.range.location)
                let qualifiers =
                    ["Self", "self"]
                    + (owner.map { [tree.scopes[$0].name] } ?? [])
                calls.insert(
                    #"(?<![\w.])(?:(?:"#
                        + qualifiers.joined(separator: "|")
                        + #")\.)?"# + name + #"\("#
                )
            }
        }
        return calls.sorted()
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
        let calls = panelFactoryCalls(
            returning: alternatives,
            in: files
        )
        let declared = try NSRegularExpression(
            pattern: #"\b(?:var|let)\s+(\w+)([^\n]*)"#
        )
        // A panel type or factory named anywhere in the declaration
        // — `NSPanel?`, `[K: [NSPanel]]`, `Set<NSPanel>`,
        // `NSPanel.init(`, `Self.makePanel()` — but never a member
        // of one (`NSWindow.Level`).
        let names = try NSRegularExpression(
            pattern: #"(?<!\w)(?:"# + alternatives
                + #")\b(?!\s*\.\s*(?!init\b)\w)|"#
                + calls.joined(separator: "|")
        )
        var owners: Set<String> = []
        var offenders: [String] = []
        for (file, text) in files {
            let ns = text as NSString
            let hits = declared.matches(
                in: text,
                range: NSRange(location: 0, length: ns.length)
            ).filter {
                let rest = ns.substring(with: $0.range(at: 2))
                // A function-typed store TAKES a panel; it holds none.
                let annotation =
                    rest.split(
                        separator: "=",
                        maxSplits: 1
                    ).first ?? ""
                if annotation.contains("->") { return false }
                return names.firstMatch(
                    in: rest,
                    range: NSRange(
                        location: 0,
                        length: (rest as NSString).length
                    )
                ) != nil
            }
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
                guard
                    SourceScan.typeKeywords.contains(
                        tree.scopes[scope].keyword
                    )
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
                    // Named on the line that orders it out.
                    let ordersItOut = body.split(separator: "\n").contains {
                        $0.contains("orderOut(")
                            && SourceScan.mentions(
                                identifier: property,
                                in: String($0)
                            )
                    }
                    return head.contains("isolated deinit") && ordersItOut
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
