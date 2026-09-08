import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktop families' one explanation (#1114): a `?` on the
/// drawer header, carrying what a Desktop is against a Space.
///
/// Separate from `ShortcutsDesktopOfferTests`, which owns
/// whether the families are WITHHELD. This owns what the door
/// says once it is there.
///
/// **The one-sentence half is asserted, not scanned.** Two
/// `guard-prover` rounds walked through a scan for it: round one
/// through `var` where the needle said `let`, round two through
/// a type Swift infers (`var help = L(…)`), a `typealias`, and a
/// single computed property branching on `keys` — that last one
/// storing nothing at all, so no walk over declarations could
/// ever see it. Each escape shipped two sentences on two doors
/// with the suite green. The invariant is an equality between
/// what the two mounts render, so it is written as one
/// (`stop patching when a class repeats`, tests.md ▸ #1021).
///
/// The scan that remains watches PLACEMENT, which has no runtime
/// value to compare: whether the `?` is the header's sibling or
/// a row inside the drawer is a fact about the view tree.
///
/// Main-actor spend (tests.md): two `makeTestModel` builds and
/// one `ShortcutsFamilyRows` fixture, as its sibling suite.
@MainActor
@Suite("Desktop shortcuts help")
struct ShortcutsDesktopHelpTests {
    private static let offerFile =
        "Sources/KiwiDesk/Settings/Components/Keybindings/"
        + "DesktopShortcutsOffer.swift"

    private static let groupsFile =
        "Sources/KiwiDesk/Settings/Components/Keybindings/"
        + "KeybindingGroups.swift"

    private func squashed(_ repoRelative: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(repoRelative)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The brace-balanced run opened by the first `{` after
    /// `marker`, or "" when the marker is absent — which every
    /// caller asserts against, since an empty run satisfies
    /// every clause below it.
    private func run(after marker: String, in source: String)
        -> String
    {
        guard let mark = source.range(of: marker) else {
            return ""
        }
        var cursor = source.distance(
            from: source.startIndex,
            to: mark.upperBound
        )
        return SourceScan.balanced(
            Array(source),
            from: &cursor,
            open: "{",
            close: "}"
        ) ?? ""
    }

    private func offer(
        keys: [SettingKey],
        drawer: SettingsDrawer<SettingsNoChildren>
    ) -> DesktopShortcutsOffer {
        DesktopShortcutsOffer(
            model: makeTestModel(),
            bindings: .constant([]),
            keys: keys,
            drawer: drawer,
            expander: ShortcutsFamilyRows(
                spaces: [],
                icons: [:],
                desktops: .init(desktops: [1, 2]),
                resizeStep: 40,
                layerNames: [KeyLayer.defaultName],
                currentLayer: KeyLayer.defaultName
            )
        )
    }

    /// ONE explanation for both doors, asserted as the equality
    /// it is. No locale is pinned and none is owed: both sides
    /// resolve in the HOST's language and the assertion is a
    /// relation between them, never an English string (#740).
    @Test("both doors say the same thing")
    func bothMountsCarryOneExplanation() {
        let focus = offer(
            keys: ShortcutsRowOrder.focusDesktopFamilies,
            drawer: SettingsCatalog.shortcuts.focusDesktops
        )
        let move = offer(
            keys: ShortcutsRowOrder.moveWindowsDesktopFamilies,
            drawer: SettingsCatalog.shortcuts.moveWindowsDesktops
        )
        #expect(!focus.helpText.isEmpty)
        #expect(
            focus.helpText == move.helpText,
            Comment(
                rawValue: "the two Desktop drawers explain "
                    + "themselves differently — one sentence, "
                    + "two doors (#1114)"
            )
        )
        // …and the sentence really interpolated the
        // profile-binding drawer rather than quoting it (#818):
        // the label is READ from the catalog, so this cannot
        // become a second hand-kept copy of it.
        #expect(
            focus.helpText.contains(
                SettingsCatalog.profiles.desktops.control.text
            )
        )
    }

    /// The `?` rides the disclosure's ACCESSORY slot, which
    /// `SettingsDisclosureAccessoryTests` holds is a sibling of
    /// the header button — inside the content it would be a row
    /// in the drawer, reachable only after opening the very
    /// thing it explains.
    @Test("the explanation hangs on the drawer header")
    func helpRidesTheAccessorySlot() throws {
        let source = try squashed(Self.offerFile)
        let accessory = run(after: "accessory:", in: source)
        #expect(
            !accessory.isEmpty,
            Comment(
                rawValue: "the Desktop drawer has no accessory "
                    + "slot — its ? is gone, or moved inside "
                    + "the drawer it explains (#1114)"
            )
        )
        #expect(accessory.contains("HelpButton("))
        // Each door names ITSELF: a fixed subject would have
        // both announcing one drawer to VoiceOver.
        #expect(accessory.contains("subject:drawer.control.text"))
    }

    /// A mount hands the offer its rows and its door, never its
    /// words. The equality above catches a divergence that
    /// SHIPS; this catches the channel for one being opened at
    /// all, which is where a reviewer can still stop it.
    @Test("neither mount hands in an explanation")
    func mountsPassOnlyTheRuledArguments() throws {
        let groups = try squashed(Self.groupsFile)
        var labels: [[String]] = []
        var cursor = groups.startIndex
        while let hit = groups.range(
            of: "DesktopShortcutsOffer(",
            range: cursor..<groups.endIndex
        ) {
            labels.append(
                Self.topLevelLabels(
                    of: groups[hit.upperBound...]
                )
            )
            cursor = hit.upperBound
        }
        #expect(labels.count == 2)
        for mount in labels {
            #expect(
                mount == [
                    "model", "bindings", "keys", "drawer",
                    "expander",
                ],
                Comment(
                    rawValue: "a Desktop mount passes an "
                        + "argument the offer's five do not "
                        + "cover — an explanation per mount is "
                        + "two sentences that must agree "
                        + "forever (#1114)"
                )
            )
        }
    }

    /// Argument labels at paren depth 1 of a call whose opening
    /// paren has already been consumed. Depth, not commas: a
    /// nested call's own labels are its business.
    private static func topLevelLabels(
        of text: Substring
    ) -> [String] {
        var labels: [String] = []
        var depth = 1
        var token = ""
        var atArgumentStart = true
        for character in text {
            switch character {
            case "(", "[":
                depth += 1
                token = ""
            case ")", "]":
                depth -= 1
                if depth == 0 { return labels }
                token = ""
            case ",":
                if depth == 1 { atArgumentStart = true }
                token = ""
            case ":":
                if depth == 1, atArgumentStart, !token.isEmpty {
                    labels.append(token)
                    atArgumentStart = false
                }
                token = ""
            default:
                token.append(character)
            }
        }
        return labels
    }
}
