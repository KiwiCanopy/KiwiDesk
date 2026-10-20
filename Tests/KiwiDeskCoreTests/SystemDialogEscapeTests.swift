import Testing

@testable import KiwiDeskCore

/// A buttoned `AXSystemDialog` takes no #2072 escape (#2239): a
/// launcher draws its panel with title-bar buttons on that subrole,
/// as Spotlight does on macOS 27, so the subrole is the launcher's
/// evidence where a bundle id is not.
@Suite("System-dialog escape (#2239)")
struct SystemDialogEscapeTests {
    private let noRules = IgnoreRules()

    /// The gate's verdict on an accessory app's raised window that
    /// lists title-bar buttons, read the way every reader reads the
    /// button: asked only where `needsTitlebarButton` says it
    /// decides.
    private func ignoresButtoned(
        _ bundleID: String,
        layer: Int,
        subrole: String
    ) -> Bool {
        FloatDetection.shouldIgnore(
            bundleID: bundleID,
            layer: layer,
            isAccessory: true,
            rules: noRules,
            titlebarButton: FloatDetection.needsTitlebarButton(
                layer: layer,
                isAccessory: true,
                bundleID: bundleID,
                subrole: subrole
            )
        )
    }

    /// Spotlight's macOS 27 panel lists title-bar buttons on an
    /// `AXSystemDialog`, which takes no escape (#2239), so no
    /// bundle entry names it (#2236); a layer-0 window of its app
    /// tiles.
    @Test("a buttoned system dialog takes no escape")
    func systemDialogTakesNoEscape() {
        #expect(
            ignoresButtoned(
                "com.apple.campo",
                layer: 23,
                subrole: "AXSystemDialog"
            )
        )
        #expect(
            !ignoresButtoned(
                "com.apple.campo",
                layer: 23,
                subrole: "AXStandardWindow"
            )
        )
        #expect(
            !ignoresButtoned(
                "com.apple.campo",
                layer: 0,
                subrole: "AXSystemDialog"
            )
        )
        #expect(
            !FloatDetection.ignoresRaisedWindows(
                bundleID: "com.apple.campo"
            )
        )
    }

    /// The subrole is read only where the rest of the condition
    /// holds, so a layer-0 or non-accessory window costs no read.
    @Test("the subrole is asked only where the escape decides")
    func subroleReadIsLazy() {
        var reads = 0
        func subrole() -> String {
            reads += 1
            return "AXStandardWindow"
        }
        _ = FloatDetection.needsTitlebarButton(
            layer: 0,
            isAccessory: true,
            bundleID: nil,
            subrole: subrole()
        )
        _ = FloatDetection.needsTitlebarButton(
            layer: 8,
            isAccessory: false,
            bundleID: "com.example.app",
            subrole: subrole()
        )
        #expect(reads == 0)
        #expect(
            FloatDetection.needsTitlebarButton(
                layer: 8,
                isAccessory: true,
                bundleID: nil,
                subrole: subrole()
            )
        )
        #expect(reads == 1)
    }
}
