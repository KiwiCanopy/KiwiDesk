import Foundation
import Testing

/// The Go to Desktop name is spelled once per catalog (#3439):
/// `shortcuts.go_to_desktop`, which the Shortcuts use `?` names, is
/// the row label `shortcuts.fold.go_to_desktop` with its Desktop
/// number taken out. One key cannot serve both, since the row's
/// frame carries the number, so every catalog is held to the
/// derivation, and a catalog holds both keys or neither.
///
/// The derivation drops `%1$@`, folds the space it leaves, and trims
/// a separator the frame put before the number (`ko`'s ":"). Trade:
/// a locale whose bare name genuinely differs from its row's stem
/// takes a row in `exceptions` with its reason, never a wider strip.
@Suite("Go to Desktop label parity (#3439)")
struct GoToDesktopLabelParityTests {
    /// Locale → why its bare name is not the row's stem; empty.
    private static let exceptions: [String: String] = [:]

    private static let nameKey = "shortcuts.go_to_desktop"
    private static let rowKey = "shortcuts.fold.go_to_desktop"

    /// The row label with its number taken out.
    static func bareName(of frame: String) -> String {
        let cut = frame.replacingOccurrences(of: "%1$@", with: "")
        let folded = cut.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return folded.trimmingCharacters(
            in: CharacterSet(charactersIn: " :：")
        )
    }

    @Test("the derivation takes out the number and its separator")
    func derivation() {
        #expect(Self.bareName(of: "Go to Desktop %1$@") == "Go to Desktop")
        #expect(
            Self.bareName(of: "Zu Schreibtisch %1$@ wechseln")
                == "Zu Schreibtisch wechseln"
        )
        let ja = Self.bareName(of: "デスクトップ%1$@へ移動")
        #expect(ja == "デスクトップへ移動")
        let ko = Self.bareName(of: "데스크탑으로 이동: %1$@")
        #expect(ko == "데스크탑으로 이동")
    }

    @Test("every catalog names the row the frame names")
    func everyCatalogAgrees() throws {
        let locales = try Self.catalogNames()
        var compared = 0
        for locale in locales where Self.exceptions[locale] == nil {
            let catalog = try Self.catalog(locale)
            switch (catalog[Self.nameKey], catalog[Self.rowKey]) {
            case (nil, nil):
                // Both fall back to English, which is compared too.
                continue
            case (let name?, let frame?):
                compared += 1
                #expect(
                    name == Self.bareName(of: frame),
                    "\(locale): \(name) vs \(frame)"
                )
            default:
                Issue.record(
                    """
                    \(locale) holds one of \(Self.nameKey) and \
                    \(Self.rowKey): the other falls back to English, \
                    so the name and the row differ. Drop or draft \
                    the pair together.
                    """
                )
            }
        }
        #expect(compared > 1, "\(compared) catalog(s) compared")
        for (locale, reason) in Self.exceptions {
            let catalog = try Self.catalog(locale)
            let name = catalog[Self.nameKey]
            let frame = catalog[Self.rowKey].map(Self.bareName(of:))
            #expect(
                locales.contains(locale) && name != frame,
                "stale exception \(locale): \(reason)"
            )
        }
    }

    private static var localesDirectory: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Resources/Locales")
    }

    /// The shipped catalogs; a worksheet left beside them is named,
    /// never skipped, since every reader of the directory decodes it.
    private static func catalogNames() throws -> [String] {
        let names = try FileManager.default
            .contentsOfDirectory(atPath: localesDirectory.path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
        for name in names where name.hasPrefix("missing_") {
            Issue.record(
                "\(name) is a worksheet in the catalog directory"
            )
        }
        return
            names
            .filter { !$0.hasPrefix("missing_") }
            .map { String($0.dropLast(".json".count)) }
    }

    private static func catalog(_ name: String) throws -> [String: String] {
        try JSONDecoder().decode(
            [String: String].self,
            from: Data(
                contentsOf: localesDirectory.appendingPathComponent(
                    "\(name).json"
                )
            )
        )
    }
}
