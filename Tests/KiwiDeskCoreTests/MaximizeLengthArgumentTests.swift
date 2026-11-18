import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A share argument is a number (a fraction) or a string ending in
/// `pt` (#3460); nothing guesses that a number above 1 means points.
/// Every setter and the press answer one refusal.
@Suite("Maximize length arguments (#3460)", .serialized)
@MainActor
struct MaximizeLengthArgumentTests {
    private let refusal =
        #"expected a share from 0.1 to 1 or a length like "800pt""#

    @Test("a number is a fraction, a pt string a length")
    func parse() {
        #expect(MaximizeLength.argument(.number(0.33)) == .fraction(0.33))
        #expect(MaximizeLength.argument(.string("1100pt")) == .points(1100))
        #expect(MaximizeLength.argument(.string("800 PT")) == .points(800))
        #expect(MaximizeLength.argument(.string("100pt")) == .points(100))
        // The table `get_settings` hands back reads as written.
        #expect(
            MaximizeLength.argument(.object(["points": .number(1280)]))
                == .points(1280)
        )
    }

    @Test("an out-of-range or unspelled share is refused")
    func refusedShapes() {
        for value: JSONValue in [
            .number(1100), .number(2), .number(0.05), .string("99pt"),
            .string("800"), .string("pt"), .string("80%"), .bool(true),
            .string("infpt"), .object(["points": .number(50)]),
            .object(["points": .number(800), "x": .number(1)]),
        ] {
            #expect(MaximizeLength.argument(value) == nil)
        }
    }

    @Test("set_share stores a length for one shape")
    func setterStoresALength() {
        let core = makeTestCore()
        let reply = core.execute(
            "maximize.set_share",
            args: [.string("height"), .string("1100pt"), .string("laptop")]
        )
        #expect(reply.isSuccess)
        let settings = core.tiler.settings.maximize
        #expect(settings.heightShare[.laptop] == .points(1100))
        #expect(settings.heightShare[.portrait] == .fraction(3 / 4))
    }

    @Test("set_share_override stores a length for one Space")
    func overrideStoresALength() {
        let core = makeTestCore()
        let reply = core.execute(
            "maximize.set_share_override",
            args: [.string("2"), .string("width"), .string("640pt")]
        )
        #expect(reply.isSuccess)
        #expect(
            core.tiler.settings.maximize.shareOverride[SpaceID("2")]?.width
                == .points(640)
        )
    }

    @Test("every door answers one refusal")
    func oneRefusal() {
        let core = makeTestCore()
        let replies = [
            core.execute(
                "maximize.set_share",
                args: [.string("height"), .number(1100)]
            ),
            core.execute(
                "maximize.set_share_override",
                args: [.string("2"), .string("height"), .string("50pt")]
            ),
            core.execute(
                "toggle_maximized",
                args: [.string("height"), .string("wide")]
            ),
        ]
        for reply in replies {
            #expect(!reply.isSuccess)
            #expect(reply.error == refusal)
        }
        #expect(core.tiler.settings.maximize == MaximizeSettings())
    }

    @Test("a press takes its own length")
    func pressTakesALength() throws {
        let core = makeTestCore()
        let shape = try core.maximizeShape(
            from: [.string("height"), .string("1100pt")],
            for: nil
        ).get()
        #expect(shape.axis == .height)
        #expect(shape.share == .points(1100))
    }
}
