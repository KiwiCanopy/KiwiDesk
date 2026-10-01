import AppKit
import Testing

@testable import KiwiDeskCore

/// A bundled look's face (#1684): one every supported macOS ships,
/// or the look draws System and files a Config Issue (#1681), and
/// one with lining figures — an old-style face's figures sit
/// below its caps' middle and read ragged as Space numbers, so it
/// stays a user's pick rather than a look's.
@Suite("Look fonts")
struct LookFontTests {
    @Test("every bundled look's face is installed with lining figures")
    @MainActor
    func liningFaces() throws {
        let size = CGSize(width: 2560, height: 1440)
        for look in LookCatalog.bundled(sizes: [size]) {
            var settings = StarterSetup.standardLayout(sizes: [size])
                .settings(sizes: [size])
            look.apply(to: &settings)
            let shelf = settings.kiwishelf
            try #require(
                BarFont.isInstalled(shelf.fontFamily),
                "\(look.name): \(shelf.fontFamily) missing"
            )
            let font = BarFont.font(
                family: shelf.fontFamily,
                weight: shelf.fontWeight,
                size: 40
            )
            let figures = CTLineGetImageBounds(
                CTLineCreateWithAttributedString(
                    NSAttributedString(
                        string: "0123456789",
                        attributes: [.font: font]
                    )
                ),
                nil
            )
            #expect(
                abs(figures.midY - font.capHeight / 2) <= 1,
                "\(look.name): \(shelf.fontFamily) figures \(figures)"
            )
        }
    }
}
