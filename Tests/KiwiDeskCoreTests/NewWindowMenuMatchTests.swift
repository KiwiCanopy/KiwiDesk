import Testing

@testable import KiwiDeskCore

/// Which File-menu row is New Window (#1518). The menus are the
/// device probe's (2026-09-30, on the issue): identifiers are
/// nib-generated and titles the app's own language, so the key
/// and a word for "window" together are the identity.
@Suite("New Window menu match")
struct NewWindowMenuMatchTests {
    private typealias Item = AXWindowActions.MenuItem

    private func item(
        _ title: String,
        _ key: String? = nil,
        _ modifiers: Int? = nil,
        enabled: Bool = true
    ) -> Item {
        Item(title: title, key: key, modifiers: modifiers, enabled: enabled)
    }

    private func match(_ items: [Item]) -> String? {
        AXWindowActions.newWindowItem(in: items).map { items[$0].title }
    }

    @Test("the probe's apps each find their own New Window")
    func probedApps() {
        // Finder, in German: ⇧⌘N is a new folder.
        #expect(
            match([
                item("Neues Fenster", "N", 0),
                item("Neuer Ordner", "N", 1, enabled: false),
                item("Neuer Tab", "T", 0),
            ]) == "Neues Fenster"
        )
        // Zen: ⇧⌘N is an EMPTY window, ⌘N the plain one.
        #expect(
            match([
                item("Neuer Tab", "T", 0),
                item("Neues leeres Fenster", "N", 1),
                item("Neues Fenster", "N", 0),
                item("Neues privates Fenster", "P", 1),
            ]) == "Neues Fenster"
        )
        // Orion: ⇧⌘N is a private window.
        #expect(
            match([
                item("New Private Window", "N", 1),
                item("New Window", "N", 0),
            ]) == "New Window"
        )
        // Antigravity (VS Code): ⌘N is a text file.
        #expect(
            match([
                item("New Text File", "N", 0),
                item("New File…", "N", 6),
                item("New Window", "N", 1),
            ]) == "New Window"
        )
    }

    @Test("an app with no such row refuses")
    func noRow() {
        // Claude: ⌘N is a session, and the window row has no key.
        #expect(
            match([
                item("Neue Sitzung", "N", 0),
                item("Neue Sitzung in neuem Fenster"),
            ]) == nil
        )
        // TextEdit's ⌘N is a document.
        #expect(match([item("Neu", "N", 0)]) == nil)
    }

    @Test("the word matches in any case, with or without accents")
    func wordForms() {
        #expect(match([item("New Finder Window", "N", 0)]) != nil)
        #expect(match([item("Nouvelle fenêtre", "N", 0)]) != nil)
        #expect(match([item("新規ウインドウ", "N", 0)]) != nil)
        #expect(match([item("Новое окно", "N", 0)]) != nil)
        #expect(match([item("New window", "n", 0)]) != nil)
    }

    /// An app's menus follow the Mac's language, not KiwiDesk's,
    /// so a language KiwiDesk does not ship still matches.
    @Test("every macOS language's New Window matches")
    func otherLanguages() {
        for title in [
            "Nieuw venster",
            "Nytt fönster",
            "Nowe okno",
            "Nové okno",
            "Nyt vindue",
            "Nytt vindu",
            "Uusi ikkuna",
            "Yeni Pencere",
            "Fereastră nouă",
            "Új ablak",
            "Novi prozor",
            "Нове вікно",
            "Jendela Baru",
            "Cửa sổ Mới",
            "Νέο παράθυρο",
            "نافذة جديدة",
            "חלון חדש",
            "नई विंडो",
            "หน้าต่างใหม่",
        ] {
            #expect(match([item(title, "N", 0)]) != nil, "\(title)")
        }
    }

    /// A disabled row still answers, so the press refuses it
    /// rather than falling through to a looser match.
    @Test("a disabled row is still the match")
    func disabledStillMatches() {
        let items = [item("New Window", "N", 0, enabled: false)]
        #expect(AXWindowActions.newWindowItem(in: items) == 0)
    }

    @Test("only ⌘N and ⇧⌘N count")
    func otherChordsDoNot() {
        #expect(match([item("New Window", "N", 2)]) == nil)
        #expect(match([item("New Window")]) == nil)
    }
}
