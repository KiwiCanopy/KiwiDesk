import Foundation
import Testing

@testable import KiwiDeskCore

/// The durable key per-Desktop state is filed under (#1147):
/// its stored spelling both ways, and that a map keyed by it
/// encodes as a JSON object rather than an array. Pure.
@Suite("Desktop key (#1147)")
struct DesktopKeyTests {
    @Test("the stored spelling round-trips both ways")
    func storedRoundTrips() {
        let id = DesktopIdentity.mint()
        expectEqual(DesktopKey.identity(id).stored, id.raw)
        expectEqual(DesktopKey.number(3).stored, "3")
        expectEqual(DesktopKey(stored: id.raw), .identity(id))
        expectEqual(DesktopKey(stored: "3"), .number(3))
    }

    /// Parsed by SHAPE, so the two can never collide: a Mission
    /// Control number is never a UUID, and a minted identity is
    /// never all digits.
    @Test("a number and an identity cannot collide")
    func shapesDoNotCollide() {
        for _ in 0..<50 {
            #expect(Int(DesktopIdentity.mint().raw) == nil)
        }
        expectEqual(DesktopKey(stored: "12").number, 12)
        #expect(DesktopKey(stored: "not-a-number").number == nil)
    }

    /// Without `CodingKeyRepresentable` Swift emits an ARRAY of
    /// alternating keys and values, which no config file of ours
    /// is shaped like and no hand edit could survive.
    @Test("a map keyed by it encodes as a JSON object")
    func mapEncodesAsAnObject() throws {
        let id = DesktopIdentity(raw: "DD641782-6F24")
        let map: [DesktopKey: String] = [
            .identity(id): "Work",
            .number(3): "Media",
        ]
        let data = try JSONEncoder().encode(map)
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])
        expectEqual(object["DD641782-6F24"] as? String, "Work")
        expectEqual(object["3"] as? String, "Media")
        let back = try JSONDecoder().decode(
            [DesktopKey: String].self,
            from: data
        )
        expectEqual(back, map)
    }

    /// The key is also a value in its own right — #1230 stores
    /// one inside a document rather than only as a map key.
    @Test("it encodes as a bare string on its own")
    func encodesAsAString() throws {
        let data = try JSONEncoder().encode(DesktopKey.number(2))
        expectEqual(String(data: data, encoding: .utf8), "\"2\"")
        #expect(
            try JSONDecoder().decode(DesktopKey.self, from: data)
                == .number(2)
        )
    }
}
