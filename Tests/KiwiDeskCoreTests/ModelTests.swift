import Testing

@testable import KiwiDeskCore

@Suite("SpaceID")
struct SpaceIDTests {
    @Test("Numeric strings and integers are equivalent")
    func numericEquivalence() {
        #expect(SpaceID("1") == SpaceID(1))
        #expect(SpaceID("01") == SpaceID(1))
        #expect(SpaceID("42") == SpaceID(42))
    }

    @Test("Named identifiers are case-sensitive")
    func caseSensitivity() {
        #expect(SpaceID("Code") != SpaceID("code"))
        #expect(SpaceID("mail") == SpaceID("mail"))
    }

    @Test("Unicode identifiers are supported")
    func unicode() {
        #expect(SpaceID("α") == SpaceID("α"))
        #expect(SpaceID("🎵").raw == "🎵")
    }

    @Test("Literals work")
    func literals() {
        let byString: SpaceID = "music"
        let byInt: SpaceID = 3
        #expect(byString.raw == "music")
        #expect(byInt == SpaceID("3"))
    }
}

@Suite("Space flat array operations")
struct SpaceTests {
    let w1 = WindowID(1)
    let w2 = WindowID(2)
    let w3 = WindowID(3)

    @Test("Append ignores duplicates")
    func appendDeduplicates() {
        var space = Space(id: "code")
        space.append(w1)
        space.append(w1)
        space.append(w2)
        #expect(space.windows == [w1, w2])
    }

    @Test("Remove clears focus and falls back")
    func removeFocused() {
        var space = Space(
            id: "code",
            windows: [w1, w2, w3],
            focused: w3
        )
        space.remove(w3)
        #expect(space.windows == [w1, w2])
        #expect(space.focused == w2)
    }

    @Test("Removing a focused middle window falls to the neighbor")
    func removeFocusedMiddle() {
        var space = Space(
            id: "code",
            windows: [w1, w2, w3],
            focused: w2
        )
        space.remove(w2)
        // The window that slid into the slot (w3), not the old
        // last window — no focus yank across the row (#158).
        #expect(space.windows == [w1, w3])
        #expect(space.focused == w3)
    }

    @Test("Swap exchanges positions")
    func swapWindows() {
        var space = Space(id: "code", windows: [w1, w2, w3])
        space.swap(w1, w3)
        #expect(space.windows == [w3, w2, w1])
    }

    @Test("Swap with unknown window is a no-op")
    func swapUnknown() {
        var space = Space(id: "code", windows: [w1, w2])
        space.swap(w1, WindowID(99))
        #expect(space.windows == [w1, w2])
    }

    @Test("Move clamps the target index")
    func moveClamps() {
        var space = Space(id: "code", windows: [w1, w2, w3])
        space.move(w1, to: 99)
        #expect(space.windows == [w2, w3, w1])
        space.move(w1, to: -5)
        #expect(space.windows == [w1, w2, w3])
    }
}

@Suite("Display")
struct DisplayTests {
    @Test("Fingerprint combines name and resolution")
    func fingerprint() {
        let display = Display(
            id: DisplayID(7),
            name: "LG 27",
            frame: .init(x: 0, y: 0, width: 2560, height: 1440)
        )
        #expect(display.fingerprint == "LG 27:2560x1440")
    }
}
