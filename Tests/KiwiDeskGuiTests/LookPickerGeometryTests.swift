import AppKit
import Testing

@testable import KiwiDesk

/// The picker's measures (#3038 ▸ Ruling 2026-11-23): the card 56 %
/// wide at 16:10, its height capped at 62 %, stripes 6 % wide and
/// 88 % of the card tall, overlapping a quarter and stopping at the
/// screen; the keys the panel reads; the quick name's fruit.
@Suite("Look picker geometry and keys (#3038)")
struct LookPickerGeometryTests {
    @Test("a laptop's card is 56 % wide at 16:10")
    func laptopCard() {
        let geometry = LookPickerGeometry(
            screen: CGSize(width: 1512, height: 982),
            menuBar: 33
        )
        let card = geometry.card
        #expect(abs(card.width - 1512 * 0.56) < 0.5)
        #expect(abs(card.width / card.height - 1.6) < 0.001)
        #expect(abs(card.midX - 756) < 0.5)
        #expect(card.midY < 982 / 2)
    }

    @Test("an ultrawide's card is capped at 62 % of the height")
    func ultrawideCap() {
        let geometry = LookPickerGeometry(
            screen: CGSize(width: 3440, height: 1440),
            menuBar: 25
        )
        #expect(abs(geometry.card.height - 1440 * 0.62) < 0.5)
        #expect(abs(geometry.card.width / geometry.card.height - 1.6) < 0.001)
    }

    @Test("stripes overlap a quarter and stop inside the screen")
    func stripes() throws {
        let geometry = LookPickerGeometry(
            screen: CGSize(width: 1512, height: 982),
            menuBar: 33
        )
        let right = geometry.stripes(side: 1, available: 40)
        let left = geometry.stripes(side: -1, available: 40)
        #expect(right.count > 1)
        #expect(left.count == right.count)
        let step = right[1].minX - right[0].minX
        #expect(abs(step - geometry.stripeSize.width * 0.75) < 0.01)
        #expect(right[0].minX < geometry.card.maxX, "tucked under the card")
        #expect(abs(right[0].height - geometry.card.height * 0.88) < 0.01)
        #expect(right.count < 40)
        let last = try #require(right.last)
        #expect(last.minX < 1512 - LookPickerGeometry.margin)
        #expect(
            last.maxX + step > 1512 - LookPickerGeometry.margin,
            "the last stripe is the one the screen cuts"
        )
        let first = try #require(left.last)
        #expect(first.maxX > LookPickerGeometry.margin)
        #expect(first.minX - step < LookPickerGeometry.margin)
        #expect(geometry.stripes(side: 1, available: 2).count == 2)
        #expect(geometry.stripes(side: 1, available: 0).isEmpty)
        #expect(
            LookPickerGeometry.stripeShade(0)
                < LookPickerGeometry.stripeShade(3)
        )
        #expect(LookPickerGeometry.stripeShade(50) == 0.7)
    }

    @Test("the panel reads arrows, ↩, Esc and ⌘S; naming hands arrows on")
    @MainActor
    func keys() {
        func key(
            _ code: UInt16,
            _ flags: NSEvent.ModifierFlags = [],
            _ char: String? = nil,
            naming: Bool = false
        ) -> LookPickerKey? {
            LookPickerPanel.key(
                keyCode: code,
                character: char,
                modifiers: flags,
                naming: naming
            )
        }
        #expect(key(123, [.numericPad, .function]) == .step(-1))
        #expect(key(124, [.numericPad, .function]) == .step(1))
        #expect(key(36) == .wear)
        #expect(key(53) == .escape)
        #expect(key(1, .command, "s") == .save)
        #expect(key(1, .command, "s", naming: true) == nil)
        #expect(key(123, [.numericPad, .function], naming: true) == nil)
        #expect(key(36, naming: true) == .commitName)
        #expect(key(123, [.shift, .numericPad, .function]) == nil)
    }

    @Test("a quick name's fruit follows the focus colour")
    func fruit() {
        #expect(LookFruit.of(hex: "#8DB354") == .kiwi)
        #expect(LookFruit.of(hex: "#E0303A") == .cherry)
        #expect(LookFruit.of(hex: "#F5A623") == .orange)
        #expect(LookFruit.of(hex: "#2F6FEB") == .blueberry)
        #expect(LookFruit.of(hex: "#F2F2F2") == .coconut)
        #expect(LookFruit.of(hex: "#1C1C1E") == .blackberry)
        #expect(LookFruit.of(hex: "nonsense") == .kiwi)
        // One hue inside each band, as ruled by ui-designer.
        let ruled: [(Double, LookFruit)] = [
            (5, .cherry), (26, .orange), (45, .mango), (61, .lemon),
            (110, .kiwi), (210, .blueberry), (272, .grape),
            (305, .plum), (332, .raspberry), (352, .cherry),
        ]
        for (hue, fruit) in ruled {
            #expect(
                LookFruit.of(hue: hue, saturation: 0.8, luminance: 0.3)
                    == fruit,
                "hue \(hue)"
            )
        }
    }
}
