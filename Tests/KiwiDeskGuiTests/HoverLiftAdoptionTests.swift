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
        #expect(strip.contains(".strokeBorder(selected?SettingsTheme."))
    }

    /// The cycle list's selected row takes its focused look only
    /// while the list holds keyboard focus in the key window, as a
    /// macOS list draws it (owner, 2026-10-17): the fill and the
    /// inks each read that one predicate. Which tokens is a tuning.
    @Test("the cycle row's focused look reads the list's focus")
    func cycleRowFollowsFocus() throws {
        let list = try source(
            "Settings/Components/Keybindings/LayoutCycleList.swift"
        )
        let focus = try body("private var listFocused:", in: list)
        #expect(focus.contains("focused!=nil"))
        #expect(focus.contains("activeState==.key"))
        let fill = try body("private func rowFill(", in: list)
        #expect(fill.contains("guardselected==modeelse{return.clear}"))
        #expect(fill.contains("returnlistFocused?SettingsTheme."))
        let item = try body("private func item(", in: list)
        #expect(item.occurrences(of: ".background(rowFill(mode))") == 1)
        #expect(item.contains("letonAccent=selected==mode&&listFocused"))
        #expect(item.occurrences(of: "onAccent?SettingsTheme.") == 2)
        // The − button and the + menu.
        #expect(squash(list).occurrences(of: ".iconHoverChip(") == 2)
    }

    /// A click always lands on the grey selection — the tap clears
    /// any focus the click kept, the row already focused included
    /// (owner device report, 2026-10-17) — and every row but the
    /// selected one lifts, on a layer apart from the selection's
    /// fill (#1173).
    @Test("a cycle row click lands grey, and the rows lift")
    func cycleRowClickAndLift() throws {
        let list = try source(
            "Settings/Components/Keybindings/LayoutCycleList.swift"
        )
        let item = try body("private func item(", in: list)
        // Cleared on a mouse tap alone, never on VoiceOver's press.
        #expect(
            item.contains(
                ".onTapGesture{picked=mode"
                    + "ifClickBornFocus.isClickBorn("
                    + "focusMayBeADescendant:false){focused=nil}}"
            )
        )
        let lift = try #require(
            item.range(of: ".rowHoverHighlight(lifts:selected!=mode")
        )
        let fill = try #require(item.range(of: ".background(rowFill(mode))"))
        #expect(lift.lowerBound < fill.lowerBound)
        #expect(item.occurrences(of: ".rowHoverHighlight(") == 1)
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
            chain.contains(
                ".menuStyle(.button).buttonStyle(.plain).neutralMenuLabel()"
            )
        )
        #expect(!menu.contains(".menuStyle(.borderlessButton)"))
        let label = try body("private var chipLabel:", in: menu)
        #expect(label.contains("targetDot(stored:"))
        #expect(
            label.contains(".padding(.horizontal,ChipMetrics.padH)")
        )
    }

    /// The scope and Space chips hand their selection to the one
    /// choice-chip surface, which owns the hover
    /// (`ChoiceChipTests` holds the surface and the sites).
    @Test("the scope and Space chips hand the surface their choice")
    func choiceChipsTakeTheSurface() throws {
        for path in [
            "Settings/Components/Keybindings/KeyboardChrome.swift",
            "Settings/Components/SpaceOverrides/SpacesPanelPreview.swift",
        ] {
            #expect(
                try squashed(path).occurrences(
                    of: ".choiceChip(selected:isOn)"
                ) == 1,
                Comment(rawValue: path)
            )
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

    /// The shortcut recorder's idle well lifts under the pointer
    /// with a fill over the well — never a ring, the armed state's
    /// vocabulary — and an armed or disabled well does not react,
    /// nor one flashing a refusal, whose `danger` label is
    /// measured on the bare well.
    @Test("the recorder's idle well lifts; an armed one does not")
    func recorderWellLifts() throws {
        let chrome = try source(
            "Settings/Components/Keybindings/Recorder/"
                + "KeyRecorderChrome.swift"
        )
        let gate = try body("private var lifted:", in: chrome)
        #expect(
            gate.contains("hovering&&isEnabled&&!recording&&!flashing")
        )
        // Every caller hands its flash in, read off every call site
        // rather than a list a new recorder could miss.
        var callers = 0
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        for url in try SourceScan.swiftSources(under: root) {
            let text = squash(
                SourceScan.stripComments(
                    try String(contentsOf: url, encoding: .utf8)
                )
            )
            for call in text.components(
                separatedBy: "RecorderButtonChrome("
            ).dropFirst() {
                let args = call.prefix { $0 != ")" }
                callers += 1
                #expect(
                    args.contains("flashing:flashing"),
                    Comment(rawValue: url.lastPathComponent)
                )
            }
        }
        #expect(callers >= 3)
        let well = squash(chrome)
        #expect(well.contains(".fill(lifted?SettingsTheme."))
        #expect(well.contains(".animation(reduceMotion?nil:"))
        #expect(well.contains(".onHover{hovering=$0}"))
        // The lift is a fill: no stroke reads it.
        #expect(!well.contains(".strokeBorder(lifted"))
    }

    /// A chord popover's entries are full-row entries: the style
    /// every entry takes lifts each one (`rowHoverHighlight`) and
    /// deepens while pressed.
    @Test("the chord popover's rows lift")
    func chordPopoverRowsLift() throws {
        let raw = try source(
            "Settings/Components/Common/ContextShortcut.swift"
        )
        let shortcut = squash(raw)
        #expect(shortcut.contains(".buttonStyle(PopoverRowStyle())"))
        #expect(!shortcut.contains(".buttonStyle(.plain)"))
        let style = try body("struct PopoverRowStyle", in: raw)
        // The press stands in for the lift: one fill, not two.
        #expect(
            style.occurrences(of: ".rowHoverHighlight(lifts:!pressed)")
                == 1
        )
        #expect(style.contains("pressed:configuration.isPressed"))
        #expect(style.contains("pressed&&isEnabled?SettingsTheme."))
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
