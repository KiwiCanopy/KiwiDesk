import Foundation
import Testing

@testable import KiwiDesk

/// Every `.sheet(` in the app's own chrome, and the two mechanics
/// the idiom carries (#859).
///
/// **This is the sheet half's register.** The panel half has one —
/// `SettingsDetailPanelOffer.offering`, a data set consulted by the
/// mount, the guards and the pill's offset alike. A sheet needs no
/// *offer* set, because a panel is one shared surface deciding per
/// destination while a sheet is per call site. What it does need is
/// a census of those call sites: gui.md states both mechanics
/// repo-wide, and before this suite they were guarded only for two
/// hardcoded paths, so sheet #2 forgot both silently (architect
/// review, 2026-08-17).
///
/// The shape is the one `ActivationPolicySeamTests` and
/// `SettingsRowShapeTests` already use — scan the trees, and let an
/// `allowed` map be the one copy of who may.
@Suite("Sheet presentation seam")
struct SheetPresentationSeamTests {
    /// Every file that may present a sheet, and the STATE it
    /// presents from.
    ///
    /// A new entry is a decision, not a formality: the host has to
    /// be a view whose identity outlives the thing that opens the
    /// sheet. `PresetsSection` hosts for its cards because they live
    /// in a `LazyVGrid` that tears down the rows it scrolls past —
    /// the same reasoning `SettingsView` follows for the one discard
    /// dialog, hosted above the `editingLua` branch its own confirm
    /// button flips.
    private static let allowed: [String: String] = [
        "PresetsSection.swift": "$previewRequest"
    ]

    private var trees: [URL] {
        ChromeScanRoots.urls(from: #filePath)
    }

    /// `item:` over an `Identifiable` request, never `isPresented:`.
    ///
    /// The reason is not about sheets — it is that a presentation
    /// whose content is built from ONE row must be handed that row,
    /// or it renders from parent state written in the same tick
    /// (#843, found on a popover). Sheets are simply where the tree
    /// has no legacy call sites to grandfather, so the rule can be
    /// absolute here while the three `.popover(isPresented:)` sites
    /// stay as they are.
    @Test("every sheet is presented by item, from an allowed host")
    func sheetsArePresentedByItem() throws {
        var seen = 0
        var files = 0
        var hosts: Set<String> = []
        var roots = 0
        for file in try trees.flatMap({
            try SourceScan.swiftSources(under: $0)
        }) {
            files += 1
            let squashed = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            let hits = squashed.occurrences(of: ".sheet(")
            guard hits > 0 else { continue }
            hosts.insert(file.lastPathComponent)
            seen += hits

            let name = file.lastPathComponent
            let state = try #require(
                Self.allowed[name],
                Comment(
                    rawValue:
                        "\(name) presents a sheet and is not in "
                        + "`allowed` — a sheet's host must be a "
                        + "view whose identity outlives its "
                        + "opener, which is a decision rather than "
                        + "a detail (gui.md ▸ a picture whose "
                        + "object is not the draft)"
                )
            )
            #expect(
                squashed.occurrences(of: ".sheet(item:\(state))")
                    == hits,
                Comment(
                    rawValue:
                        "\(name) presents a sheet by something "
                        + "other than `item: \(state)` — "
                        + "`isPresented:` builds its content from "
                        + "parent state written in the same tick "
                        + "(#843)"
                )
            )
            #expect(squashed.occurrences(of: ".sheet(isPresented:") == 0)
        }

        // Non-vacuity: the scan read real files and found the sheet
        // it is written for. A scan that matched nothing would
        // otherwise pass for having found no violations
        // (rule-authoring.md).
        #expect(files > 20)
        #expect(seen > 0)

        // **A stale entry is caught from the other direction.**
        // This replaces a clause that could not fail: it asserted
        // `allowed[name] == nil || name == "PresetsSection.swift"`
        // on the no-sheet path, and with that the map's only key,
        // the `||` exempted exactly the entry it was checking
        // (re-review, 2026-08-17). Set equality also survives one
        // host presenting TWO sheets, which the old `seen ==
        // allowed.count` did not.
        #expect(
            hosts == Set(Self.allowed.keys),
            Comment(
                rawValue:
                    "sheet hosts \(hosts.sorted()) against allowed "
                    + "\(Self.allowed.keys.sorted()) — an entry for "
                    + "a file that presents no sheet exempts it "
                    + "from this guard for free"
            )
        )

        // Root coverage, which gui.md requires of every
        // root-scanning guard: `SourceScan.swiftSources` answers
        // `[]` for a missing directory rather than throwing, so a
        // renamed root would retire half this register in silence
        // while `files > 20` stayed satisfied by `Settings/` alone.
        for root in trees {
            #expect(
                !(try SourceScan.swiftSources(under: root)).isEmpty,
                Comment(
                    rawValue:
                        "\(root.lastPathComponent) yielded no Swift "
                        + "files — the scan root moved and this "
                        + "guard went quiet"
                )
            )
            roots += 1
        }
        #expect(roots == ChromeScanRoots.paths.count)
    }

    /// A read-only sheet has one dismissal and it answers to the
    /// keyboard both ways: Return, and Escape.
    ///
    /// **Found by following the host, not by a property name.** The
    /// first cut gated on the literal `"onDone"`, which made it a
    /// name list wearing a seal's clothes — sheet #2 whose
    /// dismissal is `onClose` or `dismiss` would have been skipped
    /// entirely and forgotten Escape silently, which is the
    /// forgetting this suite exists to end (re-review, 2026-08-17).
    /// So the content type is read out of the host's own
    /// `.sheet(item:)` body and then required to carry both
    /// shortcuts.
    ///
    /// **Escape is a `.cancelAction` button, not `.onExitCommand`.**
    /// That modifier fires only while the view has focus, and this
    /// sheet holds no text field — so on a Mac with Keyboard
    /// navigation off there may be nothing in it holding focus, the
    /// exact "correct, always drawn, and reachable by nobody"
    /// shape gui.md's keyboard section records. A hidden button
    /// carrying `.keyboardShortcut(.cancelAction)` is
    /// focus-independent. A `Button` may carry one shortcut, which
    /// rules out a second modifier on the SAME button and not a
    /// second button.
    @Test("every sheet's content answers Return and Escape")
    func sheetContentTakesEscape() throws {
        var checked = 0
        for (host, _) in Self.allowed {
            let contents = try Self.contentTypes(
                presentedBy: host,
                in: trees
            )
            #expect(
                !contents.isEmpty,
                Comment(
                    rawValue:
                        "could not read \(host)'s sheet content "
                        + "type — the scan cannot then check it"
                )
            )
            for type in contents {
                let source = try Self.squashedSource(
                    of: "\(type).swift",
                    in: trees
                )
                #expect(
                    source.occurrences(
                        of: ".keyboardShortcut(.defaultAction)"
                    ) > 0,
                    Comment(rawValue: "\(type): no default action")
                )
                #expect(
                    source.occurrences(
                        of: ".keyboardShortcut(.cancelAction)"
                    ) > 0,
                    Comment(
                        rawValue:
                            "\(type) has no Escape route — "
                            + "`.onExitCommand` is not a substitute, "
                            + "it needs focus this sheet may not hold"
                    )
                )
                checked += 1
            }
        }
        #expect(checked == Self.allowed.count)
    }

    /// The content types a host presents, read from its own
    /// `.sheet(item:)` body rather than from a list here.
    private static func contentTypes(
        presentedBy host: String,
        in trees: [URL]
    ) throws -> [String] {
        let source = try squashedSource(of: host, in: trees)
        var found: [String] = []
        var rest = Substring(source)
        while let hit = rest.range(of: ".sheet(item:") {
            rest = rest[hit.upperBound...]
            // The first capitalised identifier after the closure's
            // `in` is the content type being constructed.
            guard let arrow = rest.range(of: "in") else { break }
            let tail = rest[arrow.upperBound...]
            let name = tail.prefix { $0.isLetter || $0.isNumber }
            if let first = name.first, first.isUppercase {
                found.append(String(name))
            }
        }
        return found
    }

    private static func squashedSource(
        of fileName: String,
        in trees: [URL]
    ) throws -> String {
        for root in trees {
            for file in try SourceScan.swiftSources(under: root)
            where file.lastPathComponent == fileName {
                return SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                .split(whereSeparator: \.isWhitespace)
                .joined()
            }
        }
        return ""
    }
}
