import Foundation
import Testing

/// The session sizes' one door (#764, #2921): a resize writes and
/// every overlay reads the per-Desktop layer through
/// `KiwiCore+SessionRatioWrite`, and the resolvers require the
/// door's answer, so no reader falls back to a shared value by
/// accident. No fixture can see a reader that re-derives the
/// sizes beside the door, so the spellings are counted. Fails
/// OPEN for a store reached through a name the needles do not
/// spell — a `DesktopMemory` held under another name — which
/// review carries.
@Suite("Session ratio seam (#764, #2921)")
struct SessionRatioSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let trees = ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
    private static let door = "KiwiCore+SessionRatioWrite.swift"
    private static let overlays = [
        "resolvedBsp(", "resolvedStack(", "resolvedScrolling(",
        "resolvedGrid(",
    ]

    /// The session argument a context build passes: the door, then
    /// the flip, which only `context(` takes after it.
    private static let contextDoor = try! NSRegularExpression(
        pattern: #"session: sessionRatios\((of: )?space\.id\),\s*stackFlip:"#
    )

    private func sources() throws -> [(name: String, text: String)] {
        var out: [(String, String)] = []
        for tree in Self.trees {
            let dir = Self.root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(under: dir) {
                out.append(
                    (
                        file.lastPathComponent,
                        try SourceScan.strippedSource(at: file)
                    )
                )
            }
        }
        return out
    }

    /// Every overlay call: its file and its argument list.
    private func overlayCalls() throws -> [(file: String, args: String)] {
        var out: [(String, String)] = []
        for (name, text) in try sources() {
            for needle in Self.overlays {
                var rest = Substring(text)
                while let hit = rest.range(of: needle) {
                    let before = rest[..<hit.lowerBound].suffix(5)
                    let tail = String(rest[hit.lowerBound...])
                    rest = rest[hit.upperBound...]
                    if before == "func " { continue }
                    let args = try #require(
                        SourceScan.callArguments(of: needle, in: tail)
                    )
                    out.append((name, args))
                }
            }
        }
        return out
    }

    @Test("every overlay read hands the resolver the door")
    func overlayReadsTakeTheDoor() throws {
        let sized = try overlayCalls().filter {
            $0.args.contains("session:")
        }
        #expect(sized.count >= 15)
        for call in sized {
            let subject =
                call.args
                .components(separatedBy: ",").first?
                .replacingOccurrences(of: "for:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let door =
                call.args.contains(
                    "session: sessionRatios(of: \(subject).id)"
                )
                || call.args.contains(
                    "session: self.sessionRatios(of: \(subject).id)"
                )
                // `context`'s own required parameter.
                || (call.file == "TilingSettings+Resolution.swift"
                    && call.args.contains("session: session"))
            #expect(door, "\(call.file): \(call.args)")
        }
    }

    @Test("every context build hands it the session door")
    func contextTakesTheDoor() throws {
        var found: [String: Int] = [:]
        for (name, text) in try sources() {
            let builds = text.occurrences(of: "settings.context(")
            let range = NSRange(text.startIndex..., in: text)
            let doors = Self.contextDoor.numberOfMatches(
                in: text,
                range: range
            )
            #expect(builds == doors, "\(name)")
            if doors > 0 { found[name] = doors }
        }
        #expect(
            found == [
                "TilingEngine+Layout.swift": 2,
                "KiwiCore+ResizeScrollSlot.swift": 1,
            ]
        )
    }

    @Test("the engine's seam is wired to the door once")
    func engineSeamIsWired() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
            )
        )
        #expect(source.occurrences(of: "tiler.sessionRatios = ") == 1)
        let wired = try #require(
            source.range(of: "tiler.sessionRatios = ")
        )
        let body = String(source[wired.upperBound...].prefix(120))
        #expect(body.contains("self?.sessionRatios(of: space)"))
    }

    @Test("only the door touches the store and its writer")
    func storeHasOneHome() throws {
        var store: [String: Int] = [:]
        var writer: [String: Int] = [:]
        for (name, text) in try sources() {
            let reads = text.occurrences(of: "desktopMemory.sessionRatios")
            if reads > 0 { store[name] = reads }
            let writes = text.occurrences(of: "withSessionRatios(of:")
            if writes > 0 { writer[name] = writes }
        }
        #expect(Set(store.keys) == [Self.door])
        #expect(Set(writer.keys) == [Self.door])
        let memory = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore/Profiles/DesktopMemory.swift"
            )
        )
        #expect(memory.occurrences(of: "var sessionRatios:") == 1)
    }

    @Test("the renumber, the drop and a mode change carry the sizes")
    func lifecycleIsWired() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        func body(_ path: String, after needle: String) throws -> String {
            let text = try SourceScan.strippedSource(
                at: core.appendingPathComponent(path)
            )
            return try #require(
                SourceScan.declarationBody(after: needle, in: text)
            )
        }
        #expect(
            try body(
                "Profiles/KiwiCore+HeldSpaces.swift",
                after: "private func moveMembers("
            ).contains("rekeySessionRatios(source, to: target)")
        )
        #expect(
            try body(
                "Profiles/KiwiCore+ProfileSpaces.swift",
                after: "func forwardWindows(of space: SpaceID,"
            ).contains("forgetSessionRatios(of: space)")
        )
        #expect(
            try body(
                "App/KiwiCore+TrackSeed.swift",
                after: "func setSpaceMode("
            ).contains("forgetSessionRatios(of: id)")
        )
    }
}
