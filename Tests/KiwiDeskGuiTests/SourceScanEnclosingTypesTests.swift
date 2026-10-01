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
