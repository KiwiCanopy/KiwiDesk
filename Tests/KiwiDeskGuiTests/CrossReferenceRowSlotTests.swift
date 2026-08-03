import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A `CrossReferenceRow` renders the destination's name AT the
/// position its prose puts it, which only works while the prose
/// carries `CrossReferenceRow.linkSlot`. Without one the link
/// falls to the end of the sentence — the row's old fixed-order
/// `HStack` shape — and the key has to be authored dangling
/// ("… — edit them in"), which is what forced `ja`, `ko`,
/// `zh-Hans`, `zh-Hant` and `ru` to end their translations on a
/// colon or a bare preposition. That fallback is deliberate (a
/// missed call site still renders a followable pointer rather
/// than losing navigation) and therefore silent.
///
/// **The prose is ASSERTED, not scanned for.** The first cut of
/// this suite resolved each call site's `prose:` expression to
/// its declaration and asked whether that source mentioned the
/// slot. guard-prover shipped two mutations straight past it:
/// `overrideProse` and `appBarState` both branch, and one
/// `contains` over a whole body is satisfied by whichever arm
/// still carries a slot — so the singular-space sentence and the
/// monocle sentence could each go back to dangling under a green
/// suite. That is the shipped defect reproducing, and it is the
/// same failure `LayoutSchematicCountTests` was red-proofed
/// against: a substring a scan can find while the branch beside
/// it answers nothing (gui.md, the live-preview clause). The
/// producers are `internal` and `static` for that reason, and
/// every branch is driven below.
///
/// The scan that remains does only what asserting values cannot:
/// notice a call site whose prose is not in the asserted set —
/// a NEW cross-reference. `everyRowIsAsserted` is the coupling,
/// and it reds on the fifth row rather than covering it.
///
/// Out of scope, deliberately: a CATALOG value that drops the
/// `%N$@` restores the identical dangling render for that one
/// locale. `scripts/localization_guards.py`'s specifier-drift
/// contract owns that axis for every key at once, and runs in
/// `scripts/lint.sh` — a second copy here would guard six keys
/// and imply the rest were covered.
/// `@MainActor` because the prose producers are: they are
/// members of SwiftUI views and of a type beside them, and
/// reading one off the main actor does not fail an expectation —
/// it refuses to compile, which is the good version of the trap
/// this repo has hit at runtime.
@MainActor
@Suite("Cross-reference link position")
struct CrossReferenceRowSlotTests {
    private static var slot: String { CrossReferenceRow.linkSlot }

    /// The `prose:` expression of every `CrossReferenceRow(`
    /// application in the GUI tree, as written. Whitespace is
    /// collapsed so a line break inside a call cannot change the
    /// text a comparison sees.
    ///
    /// Hand-listed on the ONE side that has to be: this is the
    /// set the value assertions below cover, so a row added
    /// without a matching assertion reds instead of being
    /// silently exempt. The other side is derived from source.
    private static let asserted: Set<String> = [
        "Self.scrollingXrefProse",
        "Self.forcedProse",
        "Self.overrideProse(overriding)",
        "LayoutCardText.appBarState( mode, on: host.appBar.enabled )",
    ]

    // MARK: - The values

    @Test func theMotionCardProsePlacesItsLink() {
        #expect(
            MotionCard.scrollingXrefProse.contains(Self.slot)
        )
    }

    @Test func theStickyMarkProsePlacesItsLink() {
        #expect(StickyMarkEditor.forcedProse.contains(Self.slot))
    }

    /// Both arms. The singular one renders whenever exactly one
    /// space overrides — the common case — and was the arm
    /// guard-prover gutted with the suite still green.
    @Test(arguments: [1, 2, 7])
    func theSpacesUsingProsePlacesItsLink(_ overriding: Int) {
        #expect(
            SpacesUsingLayout.overrideProse(overriding)
                .contains(Self.slot)
        )
    }

    /// Every layout that hosts an App Bar, in both bar states.
    /// The modes come from `appBarHost(for:)` — Core's one copy
    /// of who may show a bar, and the same authority the switch
    /// in `appBarState` is exhaustive over — so a third hosting
    /// layout arrives here without this list being edited.
    @Test func theAppBarProsePlacesItsLink() {
        let settings = TilingSettings()
        let hosting = LayoutMode.allCases.filter {
            settings.appBarHost(for: $0) != nil
        }
        #expect(!hosting.isEmpty)
        for mode in hosting {
            for on in [true, false] {
                #expect(
                    LayoutCardText.appBarState(mode, on: on)
                        .contains(Self.slot),
                    "\(mode) on=\(on) never places its link"
                )
            }
        }
    }

    // MARK: - The coupling

    /// Every rendered row's prose is one the assertions above
    /// cover. A fifth cross-reference reds here — which is the
    /// point, since nothing else would notice it was authored
    /// without a slot.
    @Test func everyRowIsAsserted() throws {
        let found = try Self.proseExpressions()
        // An enumerator over a missing directory yields nothing
        // and a set comparison against an empty set would pass
        // by matching nothing on either side. This repo has
        // shipped a source scan that read zero files and passed.
        #expect(!found.isEmpty, "no CrossReferenceRow call sites")
        #expect(found == Self.asserted)
    }

    // MARK: - Scanning

    private static func proseExpressions() throws -> Set<String> {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDesk")
        var out: Set<String> = []
        for file in try SourceScan.swiftSources(under: tree) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for call in calls("CrossReferenceRow(", in: source) {
                if let prose = argument("prose", in: call) {
                    out.insert(prose)
                }
            }
        }
        return out
    }

    /// Each application's balanced argument list.
    private static func calls(
        _ needle: String,
        in source: String
    ) -> [String] {
        let text = Array(source)
        let wanted = Array(needle)
        var out: [String] = []
        var i = 0
        while i + wanted.count <= text.count {
            guard Array(text[i..<(i + wanted.count)]) == wanted
            else {
                i += 1
                continue
            }
            var cursor = i + wanted.count - 1
            guard
                let arguments = SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            else {
                i += wanted.count
                continue
            }
            out.append(arguments)
            i = cursor
        }
        return out
    }

    /// The argument labelled `label`, whitespace-collapsed.
    private static func argument(
        _ label: String,
        in arguments: String
    ) -> String? {
        var depth = 0
        var inString = false
        var previous: Character?
        var parts: [String] = []
        var current = ""
        for character in arguments {
            if inString {
                current.append(character)
                if character == "\"", previous != "\\" {
                    inString = false
                }
                previous = character
                continue
            }
            switch character {
            case "\"": inString = true
            case "(", "[", "{": depth += 1
            case ")", "]", "}": depth -= 1
            case "," where depth == 0:
                parts.append(current)
                current = ""
                previous = character
                continue
            default: break
            }
            current.append(character)
            previous = character
        }
        parts.append(current)
        let prefix = "\(label):"
        return
            parts
            .map {
                $0.split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")
            }
            .first { $0.hasPrefix(prefix) }
            .map {
                String($0.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
            }
    }
}
