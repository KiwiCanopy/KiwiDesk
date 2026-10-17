import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// The three searchable dropdowns route through the one
/// `DropdownCursor` (owner ruling 2026-10-17): every row draws the
/// cursor through `dropdownCursorRow` and hands the pointer to
/// `hover`, the keys move, reset and commit through the model,
/// only the keyboard sets a scroll target, and no cursor row keeps
/// the grey `rowHoverHighlight` beside it — one indication only.
/// Wiring no model clause can see, so it is pinned in the source;
/// `FontFamilyPickerSeamTests` holds the font picker's scroll and
/// search half.
@Suite("Dropdown cursor wiring")
struct DropdownCursorWiringTests {
    private static let settings = "Sources/KiwiDesk/Settings/"
    private static let common = settings + "Components/Common/"

    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
        )
    }

    private static func body(
        _ opener: String,
        in path: String
    ) throws -> String {
        try #require(
            SourceScan.declarationBody(after: opener, in: source(path)),
            "\(opener) is gone from \(path)"
        )
    }

    /// Every file drawing a cursor row.
    private static let rowFiles = [
        settings + "Components/Bars/FontFamilyPicker.swift",
        common + "AppPickerButton.swift",
        common + "AppPickerRow.swift",
        common + "GuessedAppRows.swift",
        settings + "HeaderSearch+Results.swift",
    ]

    @Test("every cursor row draws the cursor and no hover lift")
    func oneIndication() throws {
        let searchRow = Self.settings + "SettingsSearchRow.swift"
        for path in Self.rowFiles + [searchRow] {
            let text = try Self.source(path)
            #expect(
                text.occurrences(of: "rowHoverHighlight") == 0,
                "\(path) draws a second, grey hover state"
            )
        }
        for path in Self.rowFiles {
            #expect(
                try Self.source(path).occurrences(of: ".dropdownCursorRow(")
                    == 1,
                "\(path) no longer draws its rows through the cursor"
            )
        }
    }

    @Test("the row modifier fills the cursor and hears every move")
    func rowModifier() throws {
        let row = try Self.body(
            "func dropdownCursorRow(",
            in: Self.common + "DropdownCursor.swift"
        )
        #expect(row.contains(".fill(DropdownRowStyle.fill(onCursor))"))
        #expect(row.contains(".onContinuousHover"))
        #expect(row.contains("onPoint()"))
        #expect(DropdownRowStyle.fill(true) == SettingsTheme.accent)
        #expect(DropdownRowStyle.fill(false) == .clear)
        #expect(
            DropdownRowStyle.secondaryInk(true)
                == SettingsTheme.accentInkSecondary
        )
        #expect(DropdownRowStyle.secondaryInk(false) == SettingsTheme.ink3)
    }

    @Test("the pointer reaches the model through hover, and never scrolls")
    func pointerRoutes() throws {
        let header = try Self.body(
            ".dropdownCursorRow(",
            in: Self.settings + "HeaderSearch+Results.swift"
        )
        #expect(header.contains("cursor.hover("))
        let row = try Self.source(Self.common + "AppPickerRow.swift")
        #expect(row.contains(".dropdownCursorRow(onCursor, onPoint: onPoint)"))
        let picker = try Self.source(Self.common + "AppPickerButton.swift")
        #expect(picker.occurrences(of: "onPoint: { hover(slot) }") == 2)
        #expect(
            picker.contains(".dropdownCursorRow(onCursor) { hover(.escape) }")
        )
        #expect(picker.contains("onPoint: { hover(.installed($0)) }"))
        let hover = try Self.body(
            "func hover(",
            in: Self.common + "AppPickerButton+Cursor.swift"
        )
        #expect(hover.contains("cursor.hover("))
        #expect(!hover.contains("scrollTarget"))
        let guessed = try Self.source(Self.common + "GuessedAppRows.swift")
        #expect(
            guessed.contains(
                ".dropdownCursorRow(onCursor) { onPoint(app.bundleID) }"
            )
        )
        #expect(
            try Self.pickerSources().reduce(0) {
                $0 + $1.occurrences(of: "scrollTarget =")
            } == 2,
            "a writer of the scroll target besides the keys and search"
        )
    }

    /// Every GUI file declaring or extending `AppPickerButton`,
    /// since its `scrollTarget` is visible to all of them.
    private static func pickerSources() throws -> [String] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let texts = try SourceScan.swiftSources(under: root).map {
            try SourceScan.strippedSource(at: $0)
        }
        let picker = texts.filter {
            $0.contains("struct AppPickerButton")
                || $0.contains("extension AppPickerButton")
        }
        #expect(picker.count == 2, "the picker's files moved")
        return picker
    }

    @Test("the app picker's keys, search and open go through the model")
    func appPickerKeys() throws {
        let path = Self.common + "AppPickerButton+Cursor.swift"
        let move = try Self.body("func move(", in: path)
        #expect(move.contains("cursor.keyMove("))
        #expect(move.contains("scrollTarget = slot"))
        #expect(move.contains("AccessibilityNotification.Announcement("))
        #expect(
            try Self.body("func commit(", in: path)
                .contains("cursor.commit(")
        )
        let searched = try Self.body("func searched(", in: path)
        #expect(searched.contains("cursor.reset(to: first"))
        #expect(searched.contains("scrollTarget = first"))
        #expect(
            try Self.body("func opened(", in: path)
                .contains("cursor.opened(")
        )
        let picker = try Self.source(Self.common + "AppPickerButton.swift")
        #expect(picker.contains(".onSubmit { commit(lists) }"))
        #expect(
            picker.contains(".onKeyPress(.downArrow) { move(1, in: lists) }")
        )
        #expect(
            picker.contains(".onKeyPress(.upArrow) { move(-1, in: lists) }")
        )
        #expect(
            picker.contains(".onChange(of: search) { _, _ in searched() }")
        )
        let showing = try Self.body(
            ".onChange(of: showing)",
            in: Self.common + "AppPickerButton.swift"
        )
        #expect(showing.contains("opened()"))
    }

    @Test("the header search's keys and query go through the model")
    func headerKeys() throws {
        let path = Self.settings + "HeaderSearch.swift"
        let move = try Self.body("func move(", in: path)
        #expect(move.contains("cursor.keyMove("))
        #expect(move.contains("AccessibilityNotification.Announcement("))
        #expect(
            try Self.body("func commitHighlighted(", in: path)
                .contains("cursor.commit(")
        )
        #expect(
            try Self.body("func resetCursor(", in: path)
                .contains("cursor.reset(to: hits.first?.id")
        )
        #expect(
            try Self.body(".onChange(of: query)", in: path)
                .contains("resetCursor()")
        )
    }

    /// The cursor's row reads on solid accent only in the inks
    /// `SettingsThemeContrastTests+DropdownCursor` measures, and
    /// the durable selection keeps `.isSelected`.
    @Test("cursor rows draw the measured inks")
    func measuredInks() throws {
        let search = try Self.source(Self.settings + "SettingsSearchRow.swift")
        #expect(
            search.contains(".foregroundStyle(DropdownRowStyle.ink(onCursor))")
        )
        #expect(search.occurrences(of: ".foregroundStyle(secondaryInk)") == 3)
        #expect(search.occurrences(of: "SettingsTheme.ink3") == 0)
        let edge = try Self.body(
            "private var modeTagEdge",
            in: Self.settings + "SettingsSearchRow.swift"
        )
        #expect(edge.contains("onCursor"))
        #expect(edge.contains("DropdownRowStyle.secondaryInk(onCursor)"))
        #expect(search.contains("Capsule().strokeBorder(modeTagEdge)"))
        #expect(search.contains("edged: onCursor"))
        let tile = try Self.body(
            "if edged",
            in: Self.settings + "SidebarTile.swift"
        )
        #expect(tile.contains(".strokeBorder(SettingsTheme.accentInk)"))
        for path in [
            Self.settings + "Components/Bars/FontFamilyPicker.swift",
            Self.common + "AppPickerRow.swift",
            Self.common + "AppPickerButton.swift",
            Self.common + "GuessedAppRows.swift",
        ] {
            #expect(
                try Self.source(path).contains(
                    ".foregroundStyle(DropdownRowStyle.ink(onCursor))"
                ),
                "\(path) leaves the cursor row's text unmeasured"
            )
        }
        let guessed = try Self.source(Self.common + "GuessedAppRows.swift")
        #expect(guessed.contains("DropdownRowStyle.secondaryInk(onCursor)"))
        let font = try Self.source(
            Self.settings + "Components/Bars/FontFamilyPicker.swift"
        )
        #expect(
            font.contains(
                ".accessibilityAddTraits(family == selection ? [.isSelected]"
            )
        )
    }
}
