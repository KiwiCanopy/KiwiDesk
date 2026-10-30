import Foundation
import Testing

/// The shape that keeps a keystroke from re-rendering every shortcut
/// row (#2783): a navigation row and the reach views it draws
/// observe nothing, and every mount draws the row `.equatable()`.
/// `NavRowEqualityTests` holds what the comparison reads; this holds
/// that nothing re-subscribes the row behind it, which no behavior
/// suite can see.
@Suite("A navigation row observes nothing")
struct NavRowRenderSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let dir = "Sources/KiwiDesk/Settings/Components/"

    private func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: Self.root.appendingPathComponent(
                    Self.dir + path
                ),
                encoding: .utf8
            )
        )
    }

    /// A subscription, or a `Binding` SwiftUI would read as one.
    private static let observers = [
        "@ObservedObject", "@EnvironmentObject", "@StateObject",
        "@Binding", "@Bindable",
    ]

    @Test("the row and its reach views hold no subscription")
    func noObservers() throws {
        for path in [
            "Keybindings/KeybindingNavRow.swift",
            "AppRules/RuleReachControl.swift",
        ] {
            let text = try source(path)
            for observer in Self.observers {
                #expect(!text.contains(observer), "\(path): \(observer)")
            }
        }
        let column = try source("Keybindings/KeyReachColumn.swift")
        let end = try #require(column.range(of: "struct KeyReachTrash"))
        let body = column[..<end.lowerBound]
        for observer in Self.observers {
            #expect(!body.contains(observer), "KeyReachColumn: \(observer)")
        }
    }

    @Test("the row keeps its rows' binding out of SwiftUI's sight")
    func bindingIsBoxed() throws {
        let text = try source("Keybindings/KeybindingNavRow.swift")
            .filter { !$0.isWhitespace }
        #expect(text.contains("privateletrows:Rows"))
        #expect(text.contains("privatestructRows{letbinding:Binding<"))
        #expect(text.components(separatedBy: "Binding<").count - 1 == 2)
    }

    /// What the body reads beside `drawn` would skip a render
    /// when it moved; only the identity `command.lua` is compared.
    @Test("the row's body draws only what it compares")
    func bodyDrawsTheComparedValue() throws {
        let text = try source("Keybindings/KeybindingNavRow.swift")
        let start = try #require(text.range(of: "var body: some View"))
        let end = try #require(
            text.range(
                of: "private var bindings:",
                range: start.upperBound..<text.endIndex
            )
        )
        let body = text[start.upperBound..<end.lowerBound]
        #expect(body.contains("drawn."))
        #expect(body.components(separatedBy: "command.").count - 1 == 1)
        #expect(body.contains(".id(command.lua)"))
        #expect(!body.contains("model."))
        #expect(!body.contains("ShortcutsReferenceBuilder."))
    }

    @Test("every mount draws the row equatable")
    func mountsAreEquatable() throws {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Sources/KiwiDesk")
        )
        var mounts = 0
        for file in files {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            var rest = text.startIndex..<text.endIndex
            while let hit = text.range(of: "NavRow(", range: rest) {
                rest = hit.upperBound..<text.endIndex
                guard let close = Self.closingParen(in: text, from: hit)
                else { continue }
                mounts += 1
                let tail = text[close...].dropFirst()
                    .drop { $0.isWhitespace }
                #expect(
                    tail.hasPrefix(".equatable()"),
                    "\(file.lastPathComponent): NavRow( not equatable"
                )
            }
        }
        #expect(mounts >= 3)
    }

    /// The paren closing the call `open` begins.
    private static func closingParen(
        in text: String,
        from open: Range<String.Index>
    ) -> String.Index? {
        var depth = 0
        var index = text.index(before: open.upperBound)
        while index < text.endIndex {
            if text[index] == "(" { depth += 1 }
            if text[index] == ")" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = text.index(after: index)
        }
        return nil
    }
}
