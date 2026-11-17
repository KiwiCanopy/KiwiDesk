import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every hand copy of `ScrollChord`'s members answers every member
/// (#3407, parity-tests.md): the stored spelling, the glyphs and the
/// tour's keycaps. The members are read off the bits, so a new
/// member reds here until each copy names it.
@MainActor
@Suite("Scroll chord mirrors")
struct ScrollChordMirrorTests {
    /// Each single bit the stored spelling names: the members.
    private static let members: [ScrollChord] = (0..<Int.bitWidth - 1)
        .map { ScrollChord(rawValue: 1 << $0) }
        .filter { !$0.spelling.isEmpty }

    @Test("the members are read, and Hyper is one")
    func membersAreRead() {
        #expect(Self.members.count >= 5)
        #expect(Self.members.contains(.hyper))
    }

    @Test("every copy names every member, each apart")
    func copiesAgree() {
        var glyphs: Set<String> = []
        var caps: Set<HotkeyModifiers> = []
        for member in Self.members {
            let glyph = ScrollChordGlyphs.text(member)
            #expect(!glyph.isEmpty, "\(member.spelling)")
            glyphs.insert(glyph)
            let keys = HotkeyModifiers(member)
            #expect(!keys.isEmpty, "\(member.spelling)")
            caps.insert(keys)
            #expect(ScrollChord(spelling: member.spelling) == member)
        }
        #expect(glyphs.count == Self.members.count)
        #expect(caps.count == Self.members.count)
    }
}
