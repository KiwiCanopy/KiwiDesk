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
        )
    )

    @Test("a built-in group shows its title")
    func builtInShowsTitle() {
        #expect(naming.shown("move_windows") == "Title of move_windows")
        #expect(naming.shown(" Layout ") == "Title of layout")
    }

    @Test("a user's group shows as written, none shows empty")
    func ownShowsAsWritten() {
        #expect(naming.shown("Move and follow") == "Move and follow")
        #expect(naming.shown("  ") == "")
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
