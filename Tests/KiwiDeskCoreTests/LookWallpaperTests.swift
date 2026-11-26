import Foundation
import Testing

@testable import KiwiDeskCore

/// A look's picture value (#3478 ▸ Key shape): one string for every
/// screen or an object keyed by screen number, decoded strictly and
/// admitted by dropping what is no library name or no screen key.
@Suite("Look wallpaper value")
struct LookWallpaperTests {
    static let a = String(repeating: "a", count: 64) + ".png"
    static let b = String(repeating: "b", count: 64) + ".jpg"

    private func decode(_ json: String) throws -> LookWallpaper {
        try JSONDecoder().decode(LookWallpaper.self, from: Data(json.utf8))
    }

    @Test("one string is one picture for every screen")
    func stringIsAll() throws {
        let value = try decode("\"\(Self.a)\"")
        #expect(value == .all(Self.a))
        #expect(value.name(forScreen: 3) == Self.a)
    }

    @Test("an object is per screen, keys spelled as numbers")
    func objectIsPerScreen() throws {
        let value = try decode("{\"1\": \"\(Self.a)\", \"2\": \"\(Self.b)\"}")
        #expect(value == .perScreen([1: Self.a, 2: Self.b]))
        let encoded = try JSONEncoder().encode(value)
        let raw = try JSONDecoder().decode(
            [String: String].self,
            from: encoded
        )
        #expect(raw == ["1": Self.a, "2": Self.b])
    }

    @Test("a screen without an entry wears the lowest-numbered one")
    func fallbackIsLowest() {
        let value = LookWallpaper.perScreen([2: Self.b, 3: Self.a])
        #expect(value.name(forScreen: 3) == Self.a)
        #expect(value.name(forScreen: 1) == Self.b)
        #expect(value.name(forScreen: 7) == Self.b)
    }

    @Test("admission drops bad keys and names, never collapsing a map")
    func admission() throws {
        let value = try decode(
            "{\"0\": \"\(Self.a)\", \"01\": \"\(Self.a)\","
                + " \"x\": \"\(Self.a)\","
                + " \"2\": \"../etc.png\", \"3\": \"\(Self.b)\"}"
        )
        #expect(value.admitted == .perScreen([3: Self.b]))
        #expect(LookWallpaper.all("photo.png").admitted == nil)
        #expect(LookWallpaper.perScreen([:]).admitted == nil)
    }

    @Test("a value of another kind refuses the decode")
    func strict() {
        #expect(throws: (any Error).self) { try decode("42") }
    }

    @Test("names covers every entry")
    func names() {
        #expect(
            LookWallpaper.perScreen([1: Self.a, 2: Self.a, 3: Self.b]).names
                == [Self.a, Self.b]
        )
    }

    @Test("a look round-trips its picture under one key")
    func lookCarriesIt() throws {
        let look = ShelfLook(
            name: "Dusk",
            style: [:],
            colors: [:],
            wallpaper: .all(Self.a)
        )
        let data = try JSONEncoder().encode(look)
        let raw =
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(raw?["wallpaper"] as? String == Self.a)
        #expect(try JSONDecoder().decode(ShelfLook.self, from: data) == look)
    }

    @Test("Use Current collapses one file to one picture")
    func collapse() {
        #expect(KiwiCore.collapsed([1: Self.a, 2: Self.a]) == .all(Self.a))
        #expect(
            KiwiCore.collapsed([1: Self.a, 2: Self.b])
                == .perScreen([1: Self.a, 2: Self.b])
        )
        #expect(KiwiCore.collapsed([:]) == nil)
    }
}
