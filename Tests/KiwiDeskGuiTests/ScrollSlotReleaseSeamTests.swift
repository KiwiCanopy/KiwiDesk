import Foundation
import Testing

/// An order write on `Space.windows` lives in the model, where
/// every reorder primitive releases the scrolling rest's slot
/// (#1353) — `Space.swap`, `move` and `reorder` — or in a
/// mode-bound `Space` extension the scrolling rest can never
/// meet. A write beside a call site is how the App Bar drop
/// reordered without releasing, and `ScrollSlotReleaseTests`
/// cannot see a route that never calls the model.
///
/// The lens, not the list: the scan finds every order-writing
/// spelling on `windows` under `Sources/KiwiDeskCore` outside
/// `Models/` and pins a per-file count, so a new site in an
/// unlisted file reds on arrival and a vanished one reds too.
/// A read (`windows.firstIndex`, `windows.filter`) is not a
/// write and is not matched. Fails OPEN for a write through a
/// helper the needles do not spell — `windows[i] = …` or a
/// `withSpace` closure assigning through a local copy — which
/// is the residue review carries.
@Suite("Scroll slot release seam")
struct ScrollSlotReleaseSeamTests {
    /// Order-writing spellings on an ARRAY named `windows`. The
    /// `WindowManager` at `state.windows` spells `remove(id)` and
    /// `removeAll(pid:)`, which these do not match; a local
    /// `let windows =` binding is a read and is skipped below.
    private static let needles = [
        "windows = ", "windows.swapAt(", "windows.insert(",
        "windows.remove(at:", "windows.removeAll {",
        "windows.removeAll(where", "windows.append(",
        "windows.sort", "windows.reverse", "windows.move(",
    ]

    /// Files outside `Models/` allowed to write the order, with
    /// today's count and the reason: a `Space` extension bound
    /// to a mode whose spaces carry no scrolling rest — `setMode`
    /// nils it on the way in (`WorkspaceManager`) — or an array
    /// that is not a Space's at all.
    private let allowed: [String: Int] = [
        // Stack promote/demote (stack mode only).
        "Layouts/Space+StackZones.swift": 2,
        // Track insertion placement (track mode only).
        "Layouts/TrackLayout+Insert.swift": 3,
        // Track head hand-off and re-seat (track mode only).
        "Layouts/TrackLayout+SpaceState.swift": 4,
        // A local copy of a quit-grid group, not a Space.
        "App/KiwiCore+Teardown.swift": 2,
    ]

    /// Occurrences of `needle` in `source` that are writes: a
    /// `let`/`var` binding named `windows` is a read of
    /// something else and is not counted.
    private static func writes(of needle: String, in source: String)
        -> Int
    {
        var count = 0
        var rest = Substring(source)
        while let hit = rest.range(of: needle) {
            let before = source[..<hit.lowerBound].suffix(4)
            if !(before.hasSuffix("let ") || before.hasSuffix("var ")) {
                count += 1
            }
            rest = rest[hit.upperBound...]
        }
        return count
    }

    @Test("order writes outside Models/ stay inside the allowlist")
    func orderWritesStayInTheModel() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let key = String(file.path.dropFirst(prefix.count))
            guard !key.hasPrefix("Models/") else { continue }
            let source = try SourceScan.strippedSource(at: file)
            let hits = Self.needles.reduce(0) {
                $0 + Self.writes(of: $1, in: source)
            }
            guard hits > 0 else { continue }
            counts[key] = hits
        }
        for (file, count) in counts.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) writes the window order \(count)× — "
                + "route it through a Space reorder primitive "
                + "(#1353) or justify and pin it here"
            #expect(allowed[file] == count, Comment(rawValue: unlisted))
        }
        for (file, expected) in allowed {
            let vanished =
                "\(file) no longer writes the order \(expected)× — "
                + "re-pin or drop its entry"
            #expect(counts[file] == expected, Comment(rawValue: vanished))
        }
    }
}
