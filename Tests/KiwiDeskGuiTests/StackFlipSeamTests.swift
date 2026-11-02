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

    /// Config-only reads that may read the authored side.
    private static let authoredSide: [String: Int] = [
        // The Space overload's base, and the Settings preview's
        // `resolved(for:activeMode:)`, which draws the authored
        // side — not ruled on #2771; raised on its PR.
        "TilingSettings+Resolution.swift": 2,
        // `get_settings`: reports the authored side by ruling.
        "TilingSettings+SpaceResolved.swift": 1,
        // The door's own fallback and the toggle's authored side.
        "KiwiCore+StackFlip.swift": 2,
    ]

    /// Config-only reads of the master count alone.
    private static let masterCountOnly: [String: Int] = [
        "KiwiCore+ZOrder.swift": 1,
        "KiwiCore+StackCommands.swift": 1,
        "KiwiCore+SwapBoundary.swift": 1,
        "SpacesGates.swift": 1,
        "LayoutDefaultsGates.swift": 1,
    ]

    /// Every `resolvedStack(` call: its file, argument list and
    /// the source after its closing paren.
    private func calls() throws -> [(
        file: String, args: String, after: String
    )] {
        var out: [(String, String, String)] = []
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
                    let after = tail.dropFirst(
                        "resolvedStack(".count + args.count + 1
                    )
                    out.append(
                        (
                            file.lastPathComponent, args,
                            String(after.prefix(40))
                        )
                    )
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
            // The flip read is the call's own subject's.
            let subject =
                call.args
                .components(separatedBy: ",").first?
                .replacingOccurrences(of: "for:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let door =
                call.args.contains("flip: stackFlip(of: \(subject).id)")
                || call.args.contains(
                    "flip: self.stackFlip(of: \(subject).id)"
                )
                // `context`'s own required parameter.
                || (call.file == "TilingSettings+Resolution.swift"
                    && call.args.hasSuffix("flip: stackFlip"))
            #expect(door, "\(call.file): \(call.args)")
        }
    }

    @Test("a config-only read is registered with its reason")
    func configOnlyIsRegistered() throws {
        var authored: [String: Int] = [:]
        var masterCount: [String: Int] = [:]
        for call in try calls() where !call.args.contains("flip:") {
            let readsCount = call.after
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .hasPrefix(".masterCount")
            if readsCount, Self.masterCountOnly[call.file] != nil {
                masterCount[call.file, default: 0] += 1
            } else {
                authored[call.file, default: 0] += 1
            }
        }
        #expect(authored == Self.authoredSide)
        #expect(masterCount == Self.masterCountOnly)
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

    @Test("only the flip file touches the store")
    func storeHasOneHome() throws {
        var found: [String: Int] = [:]
        for tree in Self.trees {
            let dir = Self.root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(under: dir) {
                let text = try SourceScan.strippedSource(at: file)
                let count = text.occurrences(of: "stackFlips")
                if count > 0 { found[file.lastPathComponent] = count }
            }
        }
        // The declaration, and every read and write in the door.
        #expect(found["DesktopMemory.swift"] == 1)
        #expect(
            Set(found.keys)
                == ["DesktopMemory.swift", "KiwiCore+StackFlip.swift"]
        )
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
