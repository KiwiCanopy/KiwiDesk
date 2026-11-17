import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A bare Space row's scope fits its cell whole in every catalog
/// (#3415): the cell is one fixed width so the Space and "Applies
/// to" columns line up, and only a titled row's pattern may be cut.
/// Measured in the font AppKit draws the title in
/// (`AppRuleScopeFit.font`) against `SettingsMetrics.appRuleScopeLabel`.
/// Main-actor spend: two string measurements per catalog.
@Suite("Bare scopes fit the scope cell in every locale (#3415)", .serialized)
@MainActor
struct AppRuleScopeWidthTests {
    @Test("All windows and All other windows fit in every catalog")
    func bareScopesFit() {
        defer { LocalizationManager.shared.select("en") }
        let font = AppRuleScopeFit.font
        let locales = LocaleCatalog.availableLocales() + ["en"]
        #expect(locales.count > 1)
        for locale in locales {
            LocalizationManager.shared.select(locale)
            for word in [AppRuleScopeWords.all, AppRuleScopeWords.allOther] {
                let width = (word as NSString)
                    .size(withAttributes: [.font: font]).width
                #expect(
                    width <= SettingsMetrics.appRuleScopeLabel,
                    "\(locale): “\(word)” is \(width) pt"
                )
            }
        }
    }
}
