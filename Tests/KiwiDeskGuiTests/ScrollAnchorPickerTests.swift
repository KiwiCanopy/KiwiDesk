import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every anchor the enum declares reaches the two pickers that
/// offer one (#753).
///
/// `ScrollingParams.Anchor` became `CaseIterable` so the sweeps
/// stop hand-listing the cases, and three suites now read
/// `allCases`. That covers a fifth anchor in the *tests* while
/// leaving it absent from the two places a user actually picks
/// one, which is the worse half of the failure: the guards go
/// green over a control that never offered it. So the pickers map
/// `allCases` too, and this holds them to it.
///
/// A source scan rather than a rendered-options assertion because
/// both option lists are built inside a `View`'s private body, and
/// because what is owed is that no THIRD picker starts a fresh
/// hand-list somewhere else in the tree.
@Suite("Scrolling anchor picker")
struct ScrollAnchorPickerTests {
    /// The label keys, and the only two files allowed to author
    /// one. Both reasons are specific: `ScrollAnchorLabel` is the
    /// shared labeller the pickers read, and the Scrolling
    /// caption names Follow with the picker's own key so every
    /// locale reads its own translation of the segment rather
    /// than the English word inside a translated sentence.
    private let allowed = [
        "ScrollAnchorLabel.swift",
        "ScrollingSchematic+Caption.swift",
    ]

    private let labelKeys = [
        "scroll_grid.anchor.center",
        "scroll_grid.anchor.start_v",
        "scroll_grid.anchor.start_h",
        "scroll_grid.anchor.end_v",
        "scroll_grid.anchor.end_h",
        "scroll_grid.anchor.follow",
    ]

    @Test("no view hand-lists the anchor labels")
    func theLabelsHaveOneAuthor() throws {
        var checked = 0
        var offenders: [String] = []
        for file in try SourceScan.swiftSources(under: guiRoot) {
            let name = file.lastPathComponent
            checked += 1
            if allowed.contains(name) { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            for key in labelKeys where source.contains(key) {
                offenders.append("\(name): \(key)")
            }
        }
        #expect(
            offenders.isEmpty,
            Comment(
                rawValue:
                    "anchor labels authored outside "
                    + "`ScrollAnchorLabel`: \(offenders) — a "
                    + "hand-listed picker omits the next anchor "
                    + "while every `allCases` sweep passes"
            )
        )
        // A walk that read nothing would pass having looked.
        #expect(checked > labelKeys.count)
    }

    /// And the pickers enumerate the enum at their own call site.
    ///
    /// Two needles per file, because either alone passes over the
    /// mutation the other catches. `allCases.map{` alone is
    /// satisfied by a derivation nothing feeds — a hand-listed
    /// `options:` beside an orphaned `anchorOptions` passed it
    /// (guard-prover, this change) — and `options:anchorOptions`
    /// alone is satisfied by a helper that hand-lists four cases.
    /// Keyed on the map WITH its receiver and on the picker
    /// argument WITH its value, over comment-stripped
    /// whitespace-free source.
    @Test("both pickers enumerate every case")
    func bothPickersReadAllCases() throws {
        let sites = [
            "Components/Layouts/LayoutCard+ScrollGrid.swift",
            "Components/SpaceOverrides/SpaceOverrideRows.swift",
        ]
        for site in sites {
            let source = try squashed(site)
            for needle in [
                "ScrollingParams.Anchor.allCases.map{",
                "options:anchorOptions",
            ] {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(site) no longer builds its anchor "
                            + "options off `\(needle)` — a fifth "
                            + "anchor would be swept green and "
                            + "never offered"
                    )
                )
            }
        }
    }

    private var guiRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    private func squashed(_ path: String) throws -> String {
        let file =
            guiRoot
            .appendingPathComponent("Settings")
            .appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }
}
