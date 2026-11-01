import Foundation
import Testing

/// The stack flip's one door (#2771): every reader of the side a
/// Space draws takes `KiwiCore.stackFlip(of:)` — the resolver
/// requires it, and the engine reads it through the one seam
/// `bootstrapCoreServices` wires — while a config-only read of
/// `resolvedStack(for: SpaceID)` is registered with its reason. No
/// fixture can see a reader that re-derives the side beside the
/// door, so the calls are counted.
@Suite("Stack flip seam (#2771)")
struct StackFlipSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let trees = ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]

    /// Config-only reads, which draw nothing: the authored side or
    /// the master count alone.
    private static let configOnly: [String: Int] = [
        // The Space overload's base, and the GUI preview's
        // `resolved(for:activeMode:)`, which draws the authored side.
        "TilingSettings+Resolution.swift": 2,
        // `get_settings`: reports the authored side by ruling.
        "TilingSettings+SpaceResolved.swift": 1,
        // The door's own fallback and the toggle's authored side.
        "KiwiCore+StackFlip.swift": 2,
        // Master count alone.
        "KiwiCore+ZOrder.swift": 1,
        "KiwiCore+StackCommands.swift": 1,
        "KiwiCore+SwapBoundary.swift": 1,
        "SpacesGates.swift": 1,
        "LayoutDefaultsGates.swift": 1,
    ]

    /// Every `resolvedStack(` call's argument list, by file.
    private func calls() throws -> [(file: String, args: String)] {
        var out: [(String, String)] = []
        for tree in Self.trees {
            let dir = Self.root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(under: dir) {
                let text = try SourceScan.strippedSource(at: file)
                var rest = Substring(text)
                while let hit = rest.range(of: "resolvedStack(") {
                    let before = rest[..<hit.lowerBound].suffix(5)
                    let tail = String(rest[hit.lowerBound...])
                    rest = rest[hit.upperBound...]
                    if before == "func " { continue }
                    let args = try #require(
                        SourceScan.callArguments(
                            of: "resolvedStack(",
                            in: tail
                        )
                    )
                    out.append((file.lastPathComponent, args))
                }
            }
        }
        return out
    }

    @Test("every drawn-side read hands the resolver the door")
    func flipCallsTakeTheDoor() throws {
        let flipped = try calls().filter { $0.args.contains("flip:") }
        #expect(flipped.count >= 8)
        for call in flipped {
            let door =
                call.args.contains("flip: stackFlip(of:")
                || call.args.contains("flip: self.stackFlip(of:")
                // `context`'s own required parameter.
                || (call.file == "TilingSettings+Resolution.swift"
                    && call.args.hasSuffix("flip: stackFlip"))
            #expect(door, "\(call.file): \(call.args)")
        }
    }

    @Test("a config-only read is registered with its reason")
    func configOnlyIsRegistered() throws {
        var found: [String: Int] = [:]
        for call in try calls() where !call.args.contains("flip:") {
            found[call.file, default: 0] += 1
        }
        #expect(found == Self.configOnly)
    }

    @Test("every context build hands it the flip door")
    func contextTakesTheDoor() throws {
        var found: [String: Int] = [:]
        let dir = Self.root.appendingPathComponent(Self.trees[0])
        for file in try SourceScan.swiftSources(under: dir) {
            let text = try SourceScan.strippedSource(at: file)
            for needle in [
                "stackFlip: stackFlip(space.id)",
                "stackFlip: stackFlip(of: space.id)",
            ] {
                let count = text.occurrences(of: needle)
                if count > 0 {
                    found[file.lastPathComponent, default: 0] += count
                }
            }
            #expect(
                text.occurrences(of: "settings.context(")
                    == text.occurrences(of: "stackFlip: stackFlip("),
                "\(file.lastPathComponent)"
            )
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
        #expect(source.occurrences(of: "tiler.stackFlip = ") == 1)
        let wired = try #require(
            source.range(of: "tiler.stackFlip = ")
        )
        let body = String(source[wired.upperBound...].prefix(120))
        #expect(body.contains("self?.stackFlip(of: space)"))
    }

    @Test("only the flip file writes the store")
    func storeHasOneWriterFile() throws {
        var found: [String: Int] = [:]
        let dir = Self.root.appendingPathComponent(Self.trees[0])
        for file in try SourceScan.swiftSources(under: dir) {
            let text = try SourceScan.strippedSource(at: file)
            let count =
                text.occurrences(of: "stackFlips =")
                + text.occurrences(of: "stackFlips[")
            if count > 0 { found[file.lastPathComponent] = count }
        }
        #expect(found.keys.sorted() == ["KiwiCore+StackFlip.swift"])
    }

    @Test("the renumber and the drop carry the flip")
    func renumberAndDropAreWired() throws {
        let profiles = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Profiles"
        )
        let held = try SourceScan.strippedSource(
            at: profiles.appendingPathComponent(
                "KiwiCore+HeldSpaces.swift"
            )
        )
        let move = try #require(
            SourceScan.declarationBody(
                after: "private func moveMembers(",
                in: held
            )
        )
        #expect(move.contains("rekeyStackFlips(source, to: target)"))
        let spaces = try SourceScan.strippedSource(
            at: profiles.appendingPathComponent(
                "KiwiCore+ProfileSpaces.swift"
            )
        )
        let drop = try #require(
            SourceScan.declarationBody(
                after: "func forwardWindows(of space: SpaceID,",
                in: spaces
            )
        )
        #expect(drop.contains("forgetStackFlips(of: space)"))
    }
}
