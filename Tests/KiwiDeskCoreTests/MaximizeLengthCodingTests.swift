import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Maximize share is a fraction or a length (#3460): a bare
/// number stays a fraction, as every earlier build wrote it, and
/// `{"points": N}` is a length; anything else throws, so no stored
/// value changes meaning and no `ConfigMigration` is owed.
@Suite("Maximize length coding (#3460)")
struct MaximizeLengthCodingTests {
    private func encoded(_ value: MaximizeLength) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    private func decoded(_ json: String) throws -> MaximizeLength {
        try JSONDecoder().decode(MaximizeLength.self, from: Data(json.utf8))
    }

    @Test("both spellings round-trip")
    func roundTrip() throws {
        for value: MaximizeLength in [.fraction(0.25), .points(1280)] {
            #expect(try decoded(encoded(value)) == value)
        }
    }

    /// The pin a downgrade reads: a fraction still writes a bare
    /// number, the shape 4.2 decodes.
    @Test("a fraction writes a bare number, a length an object")
    func encoderPin() throws {
        #expect(try encoded(.fraction(0.5)) == "0.5")
        #expect(try encoded(.points(1100)) == #"{"points":1100}"#)
    }

    @Test("a malformed share throws")
    func malformedThrows() {
        for json in [
            #""800pt""#, #"{"pt":800}"#, #"{"points":800,"x":1}"#,
            #"{"points":"800"}"#, #"{"points":50}"#, "null",
        ] {
            #expect(throws: DecodingError.self) { try decoded(json) }
        }
    }

    /// A settings file 4.2 wrote, from the old type's own encoder,
    /// reads back with every share as the same fraction.
    @Test("a 4.2 settings file keeps its fractions")
    func shippedFileKeepsItsFractions() throws {
        struct Shipped: Encodable {
            var share: [String: [String: Double]]
        }
        let data = try JSONEncoder().encode(
            Shipped(share: ["height": ["ultrawide": 1.0 / 3]])
        )
        let read = try JSONDecoder().decode(MaximizeSettings.self, from: data)
        #expect(read.heightShare[.ultrawide] == .fraction(1.0 / 3))
    }

    /// A snapshot the previous build captured keeps the `share` key
    /// and replays (#3460): the old shape from its own encoder.
    @Test("a previous build's Maximize shape replays")
    func previousSnapshotReplays() throws {
        struct Shipped: Encodable {
            var axis: MaximizeAxis?
            var share: Double
            var anchor: MaximizeAnchor
        }
        let data = try JSONEncoder().encode(
            Shipped(axis: .height, share: 0.25, anchor: .inPlace)
        )
        let read = try JSONDecoder().decode(MaximizeShape.self, from: data)
        #expect(
            read
                == MaximizeShape(
                    axis: .height,
                    share: .fraction(0.25),
                    anchor: .inPlace
                )
        )
        let length = MaximizeShape(axis: .width, share: .points(700))
        let back = try JSONDecoder().decode(
            MaximizeShape.self,
            from: JSONEncoder().encode(length)
        )
        #expect(back == length)
    }

    /// A length is never a full Maximize, whatever its size; a whole
    /// fraction still is.
    @Test("only a whole fraction is a full Maximize")
    func wholeIsFractionOnly() {
        #expect(MaximizeShape(axis: .height, share: .fraction(1)).axis == nil)
        #expect(
            MaximizeShape(axis: .height, share: .points(9000)).axis
                == .height
        )
    }

    @Test("a length matches to the half point, never a fraction")
    func matching() {
        #expect(MaximizeLength.points(800).matches(.points(800.4)))
        #expect(!MaximizeLength.points(800).matches(.points(801)))
        #expect(!MaximizeLength.points(1).matches(.fraction(1)))
        #expect(MaximizeLength.fraction(2 / 3).matches(.fraction(0.6667)))
    }
}
