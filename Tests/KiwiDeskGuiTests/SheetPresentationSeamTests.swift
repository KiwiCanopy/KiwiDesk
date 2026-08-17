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
            guard hits > 0 else {
                #expect(
                    Self.allowed[file.lastPathComponent] == nil
                        || file.lastPathComponent
                            == "PresetsSection.swift",
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) is allowed "
                            + "to host a sheet and presents none — "
                            + "a stale entry exempts a file from "
                            + "this guard for free"
                    )
                )
                continue
            }
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

        // Non-vacuity, both halves: the scan read real files, and it
        // found the sheet it is written for. A scan that matched
        // nothing would otherwise pass for having found no
        // violations (rule-authoring.md).
        #expect(files > 20)
        #expect(seen == Self.allowed.count)
    }

    /// A read-only sheet has one dismissal and it answers to the
    /// keyboard both ways.
    ///
    /// Return rides the button (`.defaultAction`); Escape cannot,
    /// because a `Button` carries one shortcut — so the host view
    /// takes `.onExitCommand`. Without it Escape is dead on a modal
    /// surface, which is "usable without a mouse" failing in its
    /// plainest form, and nothing else in the tree would notice.
    @Test("every sheet's content answers Escape")
    func sheetContentTakesEscape() throws {
        var checked = 0
        for file in try trees.flatMap({
            try SourceScan.swiftSources(under: $0)
        }) {
            let squashed = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            // The CONTENT views, found by the seal every sheet's
            // dismissal carries rather than by a name list.
            let defaultAction =
                ".keyboardShortcut(" + ".defaultAction)"
            guard squashed.occurrences(of: defaultAction) > 0,
                squashed.occurrences(of: "onDone") > 0
            else { continue }
            #expect(
                squashed.occurrences(of: ".onExitCommand") > 0,
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) has a sheet's "
                        + "default action and no Escape route"
                )
            )
            checked += 1
        }
        #expect(checked > 0)
    }
}
