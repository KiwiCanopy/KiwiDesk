import Foundation
import Testing

/// Every click target KiwiDesk draws lifts under the pointer
/// through a shared seam, and nothing a click leaves alone lifts
/// (owner rulings 2026-10-17, `docs/ui-patterns.md` ▸ Hover
/// confirms custom hit areas). Each clause pins one site's
/// ADOPTION of its seam — which seam, applied once — never the
/// token or metric the seam resolves to (tests.md).
///
/// Off the main actor: pure source reads.
@Suite("Hover lift adoption")
struct HoverLiftAdoptionTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
            .appendingPathComponent(path)
        let text = try String(contentsOf: url, encoding: .utf8)
        // A vanished file would pass every negative needle.
        #expect(text.count > 200, Comment(rawValue: path))
        return SourceScan.stripComments(text)
    }

    private func squashed(_ path: String) throws -> String {
        squash(try source(path))
    }

    private func squash(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    /// The squashed body `declaration` opens, scoping a needle to
    /// that one declaration.
    private func body(
        _ declaration: String,
        in text: String
    ) throws -> String {
        squash(
            try #require(
                SourceScan.declarationBody(after: declaration, in: text),
                Comment(rawValue: declaration)
            )
        )
    }

    /// An unselected Layouts tile lifts with a fill apart from the
    /// selection, which is the stroke alone (#1173); the selected
    /// tile stays flat (PaletteTile's shape, #2383).
    @Test("a layout tile lifts; the selected one stays flat")
    func layoutTileLifts() throws {
        let strip = try squashed(
            "Settings/Components/Layouts/LayoutStrip.swift"
        )
        #expect(strip.contains("hovered==mode&&isEnabled&&!selected"))
        #expect(strip.contains(".fill(lifted?SettingsTheme."))
        #expect(strip.contains(".onHover{insideinifinside{"))
        // Selection is the stroke alone: no accent wash.
        #expect(!strip.contains("SettingsTheme.accent.opacity("))
        #expect(strip.contains("selected?SettingsTheme.accent:"))
    }

    /// The cycle list's selected row is the accent while the list
    /// holds keyboard focus and the grey selection otherwise, as
    /// a macOS list draws it (owner, 2026-10-17).
    @Test("the cycle row is the accent only while the list is focused")
    func cycleRowFollowsFocus() throws {
        let list = try squashed(
            "Settings/Components/Keybindings/LayoutCycleList.swift"
        )
        #expect(list.contains("privatevarlistFocused:Bool{focused!=nil}"))
        #expect(
            list.contains(
                "listFocused?SettingsTheme.accent:SettingsTheme.rowSelected"
            )
        )
        #expect(list.contains(".background(rowFill(mode))"))
        #expect(list.contains("onAccent?SettingsTheme.accentInk:"))
        // The − button and the + menu.
        #expect(list.occurrences(of: ".iconHoverChip(") == 2)
    }

    /// Revert and Save a copy wash like the count button beside
    /// them; the wash does not react while disabled, and the
    /// pointing hand stays a link's.
    @Test("the pill's text actions take the one wash")
    func pillActionsWash() throws {
        #expect(
            try squashed("Settings/SettingsFooter.swift")
                .occurrences(of: ".pillHoverWash()") == 1
        )
        #expect(
            try squashed("Settings/SettingsFooter+Slots.swift")
                .occurrences(of: ".pillHoverWash()") == 2
        )
        let unsaved = try squashed("Settings/SettingsFooter+Unsaved.swift")
        #expect(unsaved.occurrences(of: ".pillHoverWash()") == 1)
        #expect(unsaved.contains("hovering&&isEnabled?"))
        #expect(!unsaved.contains(".pointingHandCursor()"))
    }

    /// The back chip and the profile chip are button chips: they
    /// rest, lift and keep their edge through the shared chip.
    @Test("the header's chips are button chips")
    func headerChipsLift() throws {
        let header = try source("Settings/SettingsHeaderBar.swift")
        let back = try body("private var backChip:", in: header)
        #expect(back.occurrences(of: ".hoverHighlight(") == 1)
        #expect(!header.contains(".chipSurface()"))
        let menu = try source("Settings/ProfileHeader.swift")
        let chain = try body("private var menu:", in: menu)
        #expect(chain.occurrences(of: ".hoverHighlight(") == 1)
        // The button menu style draws the label whole, so the dot
        // and the padding are inside the menu's hit area.
        #expect(
            chain.contains(".menuStyle(.button).buttonStyle(.plain)")
        )
        #expect(!menu.contains(".menuStyle(.borderlessButton)"))
        let label = try body("private var chipLabel:", in: menu)
        #expect(label.contains("targetDot(stored:"))
        #expect(
            label.contains(".padding(.horizontal,ChipMetrics.padH)")
        )
    }

    /// A choice chip's hover is gated on `isEnabled` where it is
    /// written, so a disabled chip never lifts (`PresetChip`).
    @Test("the scope and Space chips gate their hover")
    func choiceChipsGateHover() throws {
        for path in [
            "Settings/Components/Keybindings/KeyboardChrome.swift",
            "Settings/Components/SpaceOverrides/SpacesPanelPreview.swift",
        ] {
            let chip = try squashed(path)
            for needle in [
                ".onHover{hovering=isEnabled&&$0}",
                "hovering:hovering&&isEnabled",
                "selected:isOn,",
            ] {
                #expect(
                    chip.contains(needle),
                    Comment(rawValue: "\(path): \(needle)")
                )
            }
        }
    }

    /// Glyph-only buttons take the icon chip; the ⚠ badge drops
    /// the pointing hand, which is a link's alone.
    @Test("the icon buttons take the icon chip")
    func iconButtonsTakeTheChip() throws {
        #expect(
            try squashed("Settings/Home/UpdateStateRow.swift")
                .occurrences(of: ".iconHoverChip()") == 2
        )
        let badge = try squashed(
            "Settings/Components/Keybindings/Recorder/"
                + "KeyRecorderField+Conflict.swift"
        )
        #expect(badge.occurrences(of: ".iconHoverChip()") == 1)
        #expect(!badge.contains(".pointingHandCursor()"))
    }

    /// A chord popover's entries are full-row entries: the style
    /// every entry takes lifts each one (`rowHoverHighlight`).
    @Test("the chord popover's rows lift")
    func chordPopoverRowsLift() throws {
        let shortcut = try squashed(
            "Settings/Components/Common/ContextShortcut.swift"
        )
        #expect(shortcut.contains(".buttonStyle(PopoverRowStyle())"))
        #expect(shortcut.contains(".rowHoverHighlight()"))
        #expect(!shortcut.contains(".buttonStyle(.plain)"))
    }

    /// A link-shaped control takes the link hover — the hand and
    /// the ink lift — and states no ink of its own beneath it
    /// that would outrank the lift.
    @Test("the link sites take the link hover")
    func linksTakeTheLinkHover() throws {
        let notes = try source("Updates/UpdateNotesScroll.swift")
        let link = try body(
            "var body:",
            in: try #require(
                SourceScan.declarationBody(
                    after: "struct UpdateNotesLink",
                    in: notes
                )
            )
        )
        #expect(link.occurrences(of: ".linkHover()") == 1)
        #expect(!link.contains(".foregroundStyle("))
        let spotlight = try squashed("Updates/UpdateSpotlightRows.swift")
        #expect(
            spotlight.contains(
                "Text(UpdateSpotlightWords.showMe)Image("
            )
        )
        #expect(spotlight.occurrences(of: ".linkHover()") == 1)
        let crumb = try squashed(
            "Settings/Sections/SpacesSection+Overrides.swift"
        )
        #expect(
            crumb.contains("systemImage:\"chevron.backward\").linkHover()")
        )
        for path in [
            "Updates/UpdateNotesScroll.swift",
            "Updates/UpdateSpotlightRows.swift",
        ] {
            #expect(
                !(try squashed(path)).contains(".pointingHandCursor()"),
                Comment(rawValue: path)
            )
        }
    }
}
