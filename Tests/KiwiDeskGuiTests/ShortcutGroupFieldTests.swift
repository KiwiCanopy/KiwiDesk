import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Settings' shortcut group field (#2544 ▸ Ruling): a built-in group
/// reads as its title and is stored as its token, whether the user
/// types the title or the token; any other name is a group of its
/// own; and the menu lists built-ins, the user's own, Custom and
/// New group in that order.
@Suite("Shortcut group field")
struct ShortcutGroupFieldTests {
    /// Titles unlike their tokens, so a stored title or a shown
    /// token cannot pass by coincidence.
    private let naming = ShortcutGroupNaming(
        titles: Dictionary(
            uniqueKeysWithValues: ShortcutGroup.allCases.map {
                ($0, "Title of \($0.rawValue)")
            }
        ),
        custom: "Title of custom"
    )

    @Test("a built-in group shows its title")
    func builtInShowsTitle() {
        #expect(naming.shown("move_windows") == "Title of move_windows")
        #expect(naming.shown(" Layout ") == "Title of layout")
    }

    /// No group reads as Custom in full ink, a value rather than
    /// the field's grey hint (#2688).
    @Test("a user's group shows as written, none shows Custom")
    func ownShowsAsWritten() {
        #expect(naming.shown("Move and follow") == "Move and follow")
        #expect(naming.shown("  ") == "Title of custom")
    }

    @Test("a typed title, any case, stores the token")
    func typedTitleStoresToken() {
        #expect(naming.stored("title of move_windows") == "move_windows")
        #expect(naming.stored(" Title of focus ") == "focus")
    }

    @Test("a typed token, any case, stores the token")
    func typedTokenStoresToken() {
        #expect(naming.stored("FOCUS") == "focus")
        #expect(naming.stored("size_float") == "size_float")
    }

    @Test("any other name is stored trimmed, empty as none")
    func otherNameIsOwn() {
        #expect(naming.stored(" Swap and follow ") == "Swap and follow")
        #expect(naming.stored("   ") == "")
    }

    /// Custom shown as text must not come back as a group named
    /// Custom when typed or left in the field.
    @Test("typed Custom, any case, stores none")
    func typedCustomIsNone() {
        #expect(naming.stored(" title of CUSTOM ") == "")
        #expect(naming.committed("Title of custom", over: "focus") == "")
        #expect(naming.committed(naming.shown(""), over: "") == "")
    }

    /// An own group named like a built-in title — Lua files it by
    /// token alone — is never re-filed by a focus and a blur.
    @Test("unchanged text keeps the stored group")
    func unchangedTextKeeps() {
        let own = "Title of focus"
        #expect(naming.committed(naming.shown(own), over: own) == own)
        #expect(naming.committed("Title of focus", over: "") == "focus")
        #expect(naming.committed("Mine", over: "focus") == "Mine")
    }

    /// New group… empties the field for a name; leaving it empty
    /// keeps the group it replaced, where clearing it by hand does
    /// not.
    @Test("an empty New group keeps the group it replaced")
    func emptyNewGroupKeeps() {
        #expect(
            naming.committed("", over: "Mine", startedNew: true) == "Mine"
        )
        #expect(naming.committed("", over: "Mine") == "")
        #expect(
            naming.committed("Theirs", over: "Mine", startedNew: true)
                == "Theirs"
        )
    }

    /// The field commits through `committed`, and New group… arms
    /// the empty-keeps arm — `committed`'s cases prove nothing if the
    /// field stores `stored(text)` or never sets the flag.
    @Test("the field commits through committed, armed by New group")
    func fieldWiring() throws {
        let field = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Lua/"
                            + "ShortcutGroupField.swift"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            field.contains(
                "naming.committed(text,over:group,startedNew:startedNew)"
            )
        )
        #expect(!field.contains("naming.stored("))
        #expect(
            field.contains(
                "PullDownItem(title:newGroupTitle){startedNew=truetext=\"\""
            )
        )
    }

    @Test("the menu: built-ins, the user's own, Custom, New group")
    func menuOrder() {
        let entries = ShortcutGroupMenu.entries(
            group: "Mine",
            inUse: ["Mine", "Theirs"]
        )
        let builtIns = ShortcutGroup.allCases.map {
            ShortcutGroupMenu.builtIn($0, checked: false)
        }
        #expect(
            entries
                == builtIns + [
                    .ownHeader,
                    .own("Mine", checked: true),
                    .own("Theirs", checked: false),
                    .divider,
                    .custom(checked: false),
                    .newGroup,
                ]
        )
    }

    @Test("no groups of the user's own: no header over nothing")
    func noOwnNoHeader() {
        let entries = ShortcutGroupMenu.entries(group: "", inUse: [])
        #expect(!entries.contains(.ownHeader))
        #expect(entries.contains(.custom(checked: true)))
    }

    @Test("a built-in group is checked by its token")
    func builtInChecked() {
        let entries = ShortcutGroupMenu.entries(group: "Layout", inUse: [])
        #expect(entries.contains(.builtIn(.layout, checked: true)))
        #expect(entries.contains(.custom(checked: false)))
    }

    /// KiwiHub's bands and the field read one title per group.
    @Test("the bands and the field share the titles")
    @MainActor
    func bandsShareTitles() throws {
        LocalizationManager.shared.select("en")
        #expect(ShortcutGroup.moveWindows.title == "Move windows")
        // The field's live naming reads the same titles.
        let live = ShortcutGroupNaming.current
        #expect(live.shown("move_windows") == "Move windows")
        #expect(live.stored("move windows") == "move_windows")
        let bands = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Shortcuts/"
                            + "ShortcutsReference+Bands.swift"
                    ),
                encoding: .utf8
            )
        )
        for group in ShortcutGroup.allCases where group != .apps {
            #expect(bands.contains("ShortcutGroup.\(group).title"))
        }
    }
}
