import Foundation
import Testing

/// `SourceScan.enclosingTypes` on fixtures, because its one
/// consumer only asks about stored properties sitting directly in
/// a type body — a walk-up that stopped at the innermost scope, or
/// a member reference read as a type, would pass every log-seam
/// guard.
@Suite("SourceScan enclosing types")
struct SourceScanEnclosingTypesTests {
    private func owners(_ source: String) -> [String: String?] {
        let lines = source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let enclosing = SourceScan.enclosingTypes(of: lines)
        var byMarker: [String: String?] = [:]
        for (line, owner) in zip(lines, enclosing) {
            if let marker = line.split(separator: "@").last,
                line.contains("@")
            {
                byMarker[String(marker)] = owner
            }
        }
        return byMarker
    }

    @Test("a line inside a member resolves to its type")
    func walksUpPastMembers() {
        let found = owners(
            """
            let top = 1 // @file
            struct Outer {
                func run() {
                    let a = [1].map { $0 } // @closure
                }
                var computed: Int {
                    0 // @accessor
                }
            }
            func free() {
                let b = 2 // @free
            }
            """
        )
        #expect(found["file"] == .some(nil))
        #expect(found["closure"] == "Outer")
        #expect(found["accessor"] == "Outer")
        #expect(found["free"] == .some(nil))
    }

    @Test("a member after a closed nested type is the outer's")
    func closedSiblingIsNotTheOwner() {
        let found = owners(
            """
            final class Manager {
                struct Spec {
                    let width = 1
                }
                var onLog: Int = 0 // @after
            }
            """
        )
        #expect(found["after"] == "Manager")
    }

    @Test("a class member is its class's, never a type of its own")
    func classMembersAreNotTypes() {
        let found = owners(
            """
            class Base {
                class func make() {
                    let a = 1 // @func
                }
                class var shared: Int {
                    1 // @var
                }
                class subscript(i: Int) -> Int {
                    i // @subscript
                }
            }
            """
        )
        #expect(found["func"] == "Base")
        #expect(found["var"] == "Base")
        #expect(found["subscript"] == "Base")
    }

    @Test("a declaration line is its outer type's, a close its own")
    func declarationAndCloseLines() {
        let found = owners(
            """
            struct Outer {
                struct Inner { // @declaration
                    let x = 1
                } // @close
            }
            """
        )
        #expect(found["declaration"] == "Outer")
        #expect(found["close"] == "Inner")
    }

    /// Built from single-line literals so the fixture itself holds
    /// no `\"""`. Each emoji is two UTF-16 units that blanking
    /// turns into one space: a reading that took offsets from the
    /// unblanked lines lands past `Inner`'s brace.
    @Test("a wide or multi-line literal shifts no line")
    func literalsKeepLineStarts() {
        let found = owners(
            [
                "struct Outer {",
                "    let wide = \"" + String(repeating: "👋", count: 24)
                    + "\"",
                "    let tall = \"\"\"",
                "        enum Fake {",
                "        \"\"\"",
                "    struct Inner { // @declaration",
                "        let x = 1 // @inside",
                "    }",
                "}",
            ].joined(separator: "\n")
        )
        #expect(found["declaration"] == "Outer")
        #expect(found["inside"] == "Inner")
    }

    @Test("extension and protocol count as types")
    func extensionAndProtocolPush() {
        let found = owners(
            """
            extension Outer {
                var x: Int { 1 } // @extension
            }
            protocol Shape {
                var y: Int { get } // @protocol
            }
            """
        )
        #expect(found["extension"] == "Outer")
        #expect(found["protocol"] == "Shape")
    }

    @Test("a member reference or a literal never names a type")
    func referencesAndLiteralsAreNotTypes() {
        let found = owners(
            """
            struct Walker {
                func f(k: Kind) {
                    switch k {
                    case .class, .enum:
                        _ = [1].map {
                            $0 // @reference
                        }
                    }
                    let s = "one class Fake {"
                    _ = [s].map {
                        $0 // @literal
                    }
                }
            }
            """
        )
        #expect(found["reference"] == "Walker")
        #expect(found["literal"] == "Walker")
    }
}
