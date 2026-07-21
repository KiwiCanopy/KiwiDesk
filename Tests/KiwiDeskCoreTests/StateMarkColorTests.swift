import AppKit
import Testing

@testable import KiwiDeskCore

/// The sticky / floating mark color (#429): the `sticky.color` /
/// `floating.color` state-color pair, its empty "Automatic"
/// sentinel, and the shared resolver that keeps GUI and Lua
/// paths agreeing on what "Automatic" means.
@Suite("State mark color")
@MainActor
struct StateMarkColorTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-mark-\(UUID().uuidString)"
                )
        )
    }

    @Test("mark resolves empty to the adaptive fallback")
    func resolverEmpty() {
        // Empty = "Automatic": the fallback itself, NEVER the
        // accent-color path `NSColor(kiwiHex:)` takes on a bad
        // parse — an empty mark means "adapt", not "broken".
        #expect(NSColor.mark(hex: "", fallback: .labelColor) == .labelColor)
    }

    @Test("mark resolves a hex to that color")
    func resolverHex() {
        let red = NSColor.mark(hex: "#FF0000", fallback: .labelColor)
        let srgb = red.usingColorSpace(.sRGB)
        #expect(srgb?.redComponent == 1)
        #expect(srgb?.greenComponent == 0)
        #expect(red != NSColor.labelColor)
    }

    @Test("contrastingGlyph picks a legible black/white")
    func contrastGlyph() {
        // Light fill → black glyph; dark fill → white glyph.
        #expect(NSColor.white.contrastingGlyph == .black)
        #expect(NSColor.black.contrastingGlyph == .white)
        // A mid/dark brand hue biases to white (threshold 0.6).
        #expect(
            NSColor(kiwiHex: "#4E9F3D").contrastingGlyph == .white
        )
    }

    @Test("styles default to the Automatic sentinel")
    func defaultsAutomatic() {
        #expect(StickyStyle().color == "")
        #expect(FloatingStyle().color == "")
    }

    @Test("sticky.set_color stores a valid hex, unclamped")
    func setStickyColor() {
        let core = makeCore()
        #expect(
            core.execute(
                "sticky.set_color",
                args: [.string("#4E9F3D")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.stickyStyle.color == "#4E9F3D"
        )
    }

    @Test("floating.set_color stores a valid hex")
    func setFloatingColor() {
        let core = makeCore()
        #expect(
            core.execute(
                "floating.set_color",
                args: [.string("#E8A33D")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.floatingStyle.color == "#E8A33D"
        )
    }

    @Test("an empty string sets Automatic; junk is rejected")
    func emptyAndInvalid() {
        let core = makeCore()
        core.tiler.settings.stickyStyle.color = "#123456"
        // Empty is the valid "Automatic" reset, not a failure.
        #expect(
            core.execute(
                "sticky.set_color",
                args: [.string("")]
            ).isSuccess
        )
        #expect(core.tiler.settings.stickyStyle.color == "")
        // A non-empty non-hex is rejected and leaves the value.
        #expect(
            !core.execute(
                "sticky.set_color",
                args: [.string("bright green")]
            ).isSuccess
        )
        #expect(core.tiler.settings.stickyStyle.color == "")
        #expect(
            !core.execute(
                "floating.set_color",
                args: [.string("nope")]
            ).isSuccess
        )
    }

    @Test("set_color verbs are dispatchable")
    func listedInReference() {
        for verb in ["sticky.set_color", "floating.set_color"] {
            #expect(APIReference.dispatchable.contains(verb))
        }
    }
}
