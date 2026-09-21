import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The bespoke-container half of `ShortcutsCensusRenderTests`,
/// split at the §2.1 ceiling (#1440): which containers are drawn
/// by bespoke views is DERIVED from the source, not restated.
///
/// An earlier draft compared the declared set to a literal copy
/// of itself, which reds only when someone edits the set — the
/// very action it exists to compel — and stays green on the
/// failure it names: a container quietly going bespoke with the
/// set untouched. `gui.md` claimed it was enforced, so the claim
/// had to become true or go.
@Suite("Shortcuts bespoke containers")
struct ShortcutsBespokeContainerTests {
    /// The signal is the renderer's own shape: a census-driven
    /// container's order list is walked by a `ForEach` somewhere
    /// under `Sources/KiwiDesk`; a bespoke one's is read only by
    /// this suite. So the scan asks which `ShortcutsRowOrder`
    /// lists appear inside a `ForEach(` and maps them back to
    /// their containers.
    @Test("bespoke containers are the ones no ForEach walks")
    func bespokeContainersAreDeclared() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var rendered = ""
        for file in try SourceScan.swiftSources(under: root) {
            rendered += SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
        }
        // Each order list, and the container it serves.
        let lists: [(String, SettingsContainer)] = [
            ("focusAtRest", .focus),
            ("moveWindowsAtRest", .moveWindows),
            ("sizeAndFloatAtRest", .sizeAndFloat),
            ("sizeAndFloatMore", .sizeAndFloat),
            ("generalKeysMore", .generalKeys),
            ("openApplicationsAtRest", .openApplications),
            ("layersMore", .layers),
            ("luaBindingsMore", .luaBindings),
            ("luaBindingsAtRest", .luaBindings),
            ("defaultShortcutsAtRest", .defaultShortcuts),
            // Walked by `DesktopShortcutsOffer`, which takes its
            // list as a `keys:` PARAMETER rather than walking it
            // here — so `isWalked` reads the `ForEach` inside
            // that view. Without these two rows the register
            // silently stops being the census of this area's
            // order lists (#1125, architect + code review).
            ("focusDesktopFamilies", .focus),
            ("moveWindowsDesktopFamilies", .moveWindows),
            // Same shape, one mount: `TrackShortcutsOffer(keys:)`
            // (#1440).
            ("moveWindowsTrackFamilies", .moveWindows),
        ]
        // The table above is a CENSUS of the order lists, held
        // both ways against the declarations themselves (#1121):
        // a list added to `ShortcutsRowOrder` and left out of the
        // table was invisible — its container could be walked
        // while `bespokeContainers` still named it and this suite
        // read green. The compiler closes the rename case; this
        // closes the addition.
        #expect(!rendered.isEmpty)
        let declared = try Self.declaredOrderLists(under: root)
        #expect(!declared.isEmpty)
        #expect(
            declared == Set(lists.map(\.0)),
            Comment(
                rawValue: "order lists not in the census: "
                    + "\(declared.subtracting(lists.map(\.0)).sorted())"
                    + "; census rows with no list: "
                    + "\(Set(lists.map(\.0)).subtracting(declared).sorted())"
            )
        )
        // Squeezed once: a parameter mount is wrapped across
        // lines by the formatter, so the needle for it cannot
        // be matched against the source as written.
        let squeezed = rendered.split(
            whereSeparator: \.isWhitespace
        )
        .joined()
        var walked: Set<SettingsContainer> = []
        for (name, container) in lists
        where isWalked(name, in: rendered, squeezed: squeezed) {
            walked.insert(container)
        }
        let all = Set(lists.map(\.1))
        #expect(
            ShortcutsRowOrder.bespokeContainers
                == all.subtracting(walked)
        )
        #expect(
            ShortcutsRowOrder.bespokeContainers
                .isSubset(
                    of:
                        ShortcutsCensusRenderTests.containers(
                            of: .shortcuts
                        )
                )
        )
    }

    /// Every `static let <name>: [SettingKey]` declared in
    /// `ShortcutsRowOrder.swift` — the order lists, read off the
    /// one file that declares them. `[[SettingKey]]`
    /// (`interleavedRuns`) is a re-ordering hint over rows the
    /// lists already place, not a list serving a container, and
    /// the type pattern leaves it out.
    private static func declaredOrderLists(
        under root: URL
    ) throws -> Set<String> {
        let file =
            root
            .appendingPathComponent("Settings")
            .appendingPathComponent("Components")
            .appendingPathComponent("Keybindings")
            .appendingPathComponent("ShortcutsRowOrder.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        return Set(
            SourceScan.allMatches(
                in: source,
                pattern: #"static let (\w+): \[SettingKey\]"#
            )
        )
    }

    /// Whether a `ForEach(` anywhere in `source` walks the named
    /// order list. Matched within the `ForEach`'s own balanced
    /// parentheses so an unrelated mention nearby cannot count.
    ///
    /// A list handed to a view as a parameter counts as walked
    /// too (#1125): `DesktopShortcutsOffer(keys:)` puts the
    /// `ForEach` one file over, and reading only the literal
    /// walk would classify a rendered container as bespoke.
    private func isWalked(
        _ list: String,
        in source: String,
        squeezed: String
    ) -> Bool {
        if squeezed.contains("keys:ShortcutsRowOrder.\(list)") {
            return true
        }
        let characters = Array(source)
        let needle = Array("ForEach")
        var index = 0
        while index + needle.count < characters.count {
            guard
                Array(
                    characters[index..<(index + needle.count)]
                ) == needle
            else {
                index += 1
                continue
            }
            var cursor = index + needle.count
            let body = SourceScan.balanced(
                characters,
                from: &cursor,
                open: "(",
                close: ")"
            )
            if body?.contains("ShortcutsRowOrder.\(list)")
                == true
            {
                return true
            }
            index += needle.count
        }
        return false
    }
}
