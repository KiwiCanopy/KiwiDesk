import Foundation

// Brace scopes with their declaring keyword, for guards that ask
// which TYPE owns a declaration and which members sit inside it.
//
// Here rather than in its first consumer for the reason the
// family exists (tests.md ▸ source-scanning primitives): a second
// privately-owned brace walker beside `balanced` is the "harden
// one copy and not the other" harm, and `enclosingTypes` reads
// this tree rather than walking braces itself. It walks BLANKED
// source (`blankingCommentsAndLiterals`), so no brace inside a
// literal or comment is counted, and
// `SourceScanScopesTests` ▸ `nothingGoesDark` holds it to every
// class declaration in Core, measured outside the walker.
extension SourceScan {
    /// One brace scope, named by the last declaration keyword
    /// ahead of its `{` — `class`, `struct`, `func`, `deinit`,
    /// `var` (a computed or observed property), `if`… — or empty
    /// for a bare closure.
    struct Scope {
        let keyword: String
        let name: String
        /// Offset of the `{`.
        let open: Int
        let parent: Int?
    }

    /// Every scope of one blanked file.
    struct ScopeTree {
        var scopes: [Scope] = []
        /// Scope index → offset of its `}`.
        var close: [Int: Int] = [:]
        /// Offset → the innermost scope open there; absent at
        /// file scope.
        var innermost: [Int: Int] = [:]

        /// The text between a scope's braces.
        func body(_ index: Int, in text: NSString) -> String? {
            guard let end = close[index] else { return nil }
            let open = scopes[index].open
            return text.substring(
                with: NSRange(location: open, length: end - open)
            )
        }

        /// The class or actor owning scope `index`: itself, or
        /// the nearest enclosing one past any struct, enum or
        /// extension LEXICALLY around it — a struct declared at
        /// top level has none.
        func owningClass(of index: Int) -> Int? {
            var cursor: Int? = index
            while let current = cursor {
                let keyword = scopes[current].keyword
                if keyword == "class" || keyword == "actor" {
                    return current
                }
                cursor = scopes[current].parent
            }
            return nil
        }
    }

    /// The lookbehind keeps a member reference — `case .class,
    /// .enum:` — from naming the closure after it a type.
    private static let scopeKeyword = try! NSRegularExpression(
        pattern: #"(?<!\.)\b(class|struct|enum|actor|extension|protocol|"#
            + #"func|init|deinit|var|let|if|guard|for|while|"#
            + #"switch|else|do|catch|get|set|willSet|didSet|"#
            + #"defer|repeat)\b\s*(\w*)"#
    )

    /// The scope tree of `text`, which must already be blanked;
    /// a `{` in a live literal would otherwise open a scope.
    static func scopeTree(of text: NSString) -> ScopeTree {
        var tree = ScopeTree()
        var stack: [Int] = []
        var segmentStart = 0
        for i in 0..<text.length {
            let unit = text.character(at: i)
            if let top = stack.last { tree.innermost[i] = top }
            switch unit {
            case 123:  // {
                let hit = scopeKeyword.matches(
                    in: text as String,
                    range: NSRange(
                        location: segmentStart,
                        length: i - segmentStart
                    )
                ).last
                let group = { (n: Int) in
                    hit.map { text.substring(with: $0.range(at: n)) }
                        ?? ""
                }
                tree.scopes.append(
                    Scope(
                        keyword: group(1),
                        name: group(2),
                        open: i,
                        parent: stack.last
                    )
                )
                stack.append(tree.scopes.count - 1)
                segmentStart = i + 1
            case 125:  // }
                if let top = stack.popLast() { tree.close[top] = i }
                segmentStart = i + 1
            case 59:  // ;
                segmentStart = i + 1
            default:
                break
            }
        }
        return tree
    }

    /// Whether `identifier` occurs in `text` as a whole word —
    /// `panel` is not found inside `panels` or `panelFrame`.
    static func mentions(identifier: String, in text: String) -> Bool {
        var cursor = text.startIndex
        while let hit = text.range(
            of: identifier,
            range: cursor..<text.endIndex
        ) {
            cursor = hit.upperBound
            let before =
                hit.lowerBound == text.startIndex
                ? nil : text[text.index(before: hit.lowerBound)]
            let after =
                hit.upperBound == text.endIndex
                ? nil : text[hit.upperBound]
            let bounded = [before, after].allSatisfy {
                $0.map { !isIdentifier($0, orDot: false) } ?? true
            }
            if bounded { return true }
        }
        return false
    }
}
