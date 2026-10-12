import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The words of a Jump to window row (#1875 ▸ Rows): Core hands
/// over facts, the panel narrates them (#96). Each test pins the
/// locale first (tests.md).
@Suite("Jump to window row text")
@MainActor
struct JumpRowTextTests {
    private typealias Row = JumpListTests

    @Test("a numbered Space keeps the noun, a named one is its name")
    func spaceNames() {
        LocalizationManager.shared.select("en")
        #expect(JumpRowText.spaceName("4") == "Space 4")
        #expect(JumpRowText.spaceName("term") == "term")
    }

    @Test("the column names the status where it is not a Space")
    func places() {
        LocalizationManager.shared.select("en")
        let shown = Row.row(1, "A", space: "term")
        #expect(JumpRowText.place(of: shown)?.text == "term")
        // Under their headers: a minimized window names its Space,
        // a hidden app nothing (owner eyeball, 2026-10-12).
        #expect(
            JumpRowText.place(
                of: Row.row(1, "A", space: "4", status: .minimized)
            )?.text == "Space 4"
        )
        #expect(
            JumpRowText.place(
                of: Row.row(1, "A", space: nil, status: .minimized)
            ) == nil
        )
        #expect(
            JumpRowText.place(
                of: Row.row(1, "A", status: .fullscreen)
            )?.text == "Full Screen"
        )
        #expect(JumpRowText.place(of: Row.row(1, "A", hidden: true)) == nil)
        let nowhere = Row.row(1, "A", space: nil)
        #expect(JumpRowText.place(of: nowhere) == nil)
    }

    @Test("the Desktop shows only for a window on an unshown one")
    func desktopSuffix() {
        LocalizationManager.shared.select("en")
        let away = Row.row(
            1,
            "A",
            space: "4",
            status: .away(desktop: 2)
        )
        #expect(
            JumpRowText.place(of: away)?.text == "Space 4 · Desktop 2"
        )
        let unnamed = Row.row(
            1,
            "A",
            space: nil,
            status: .away(desktop: 3)
        )
        #expect(JumpRowText.place(of: unnamed)?.text == "Desktop 3")
        let unread = Row.row(
            1,
            "A",
            space: "4",
            status: .away(desktop: nil)
        )
        #expect(JumpRowText.place(of: unread)?.text == "Space 4")
    }

    @Test("VoiceOver reads app, title, Space, Desktop")
    func spoken() {
        LocalizationManager.shared.select("en")
        let away = Row.row(
            1,
            "Notes",
            "3.0.0 ideas",
            space: "notes",
            status: .away(desktop: 2)
        )
        #expect(
            JumpRowText.spoken(away)
                == "Notes, 3.0.0 ideas, notes, Desktop 2"
        )
        #expect(
            JumpRowText.spoken(Row.row(1, "Mail", "Inbox", space: nil))
                == "Mail, Inbox"
        )
        #expect(
            JumpRowText.spoken(Row.row(1, "Mail", space: "4"))
                == "Mail, Space 4"
        )
        #expect(
            JumpRowText.spoken(Row.row(1, "Spotify", hidden: true))
                == "Spotify, Hidden"
        )
        // VoiceOver keeps the status the header now draws.
        #expect(
            JumpRowText.spoken(
                Row.row(1, "Mail", space: "4", status: .minimized)
            ) == "Mail, Minimized"
        )
    }

    @Test("the matched letters are bold in the original title")
    func boldMatch() throws {
        LocalizationManager.shared.select("en")
        let entry = Row.row(1, "Zen", "Ghöstty notes")
        let match = try #require(
            JumpSearch.matches([entry], query: "ghost").first
        )
        let text = JumpTitle.attributed(match)
        #expect(String(text.characters) == "Zen · Ghöstty notes")
        let bold = text.runs.filter {
            $0.inlinePresentationIntent == .stronglyEmphasized
        }.map { String(text[$0.range].characters) }
        #expect(bold == ["Ghöst"])
        // No title: the app alone, its own match bold.
        let bare = JumpSearch.matches(
            [Row.row(2, "Ghostty")],
            query: "gh"
        )
        let app = JumpTitle.attributed(bare[0])
        #expect(String(app.characters) == "Ghostty")
        let appBold = app.runs.filter {
            $0.inlinePresentationIntent == .stronglyEmphasized
        }.map { String(app[$0.range].characters) }
        #expect(appBold == ["Gh"])
    }
}
