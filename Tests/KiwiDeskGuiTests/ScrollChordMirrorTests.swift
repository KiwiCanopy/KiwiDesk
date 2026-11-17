import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every hand copy of `ScrollChord`'s members answers every member
/// (#3407, parity-tests.md): the event reader, the stored spelling,
/// the glyphs and the tour's keycaps. The members are the bits ANY
/// copy names, so a member one copy learns reds here until every
/// copy names it. Its residue: a member no copy names at all.
@MainActor
@Suite("Scroll chord mirrors")
struct ScrollChordMirrorTests {
    /// The bits the event reader builds with every flag held.
    private static var read: ScrollChord {
        ScrollChord(
            flags: [.maskControl, .maskAlternate, .maskShift, .maskCommand],
            hyper: true
        )
    }

    /// Each single bit some copy names: the members.
    private static let members: [ScrollChord] = (0..<Int.bitWidth - 1)
        .map { ScrollChord(rawValue: 1 << $0) }
        .filter {
            !$0.spelling.isEmpty || read.contains($0)
                || !ScrollChordGlyphs.text($0).isEmpty
                || !HotkeyModifiers($0).isEmpty
        }

    @Test("the members are read, and Hyper is one")
    func membersAreRead() {
        #expect(!Self.members.isEmpty)
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
            #expect(!member.spelling.isEmpty, "\(member.rawValue)")
            #expect(ScrollChord(spelling: member.spelling) == member)
            #expect(Self.read.contains(member), "\(member.rawValue)")
        }
        #expect(glyphs.count == Self.members.count)
        #expect(caps.count == Self.members.count)
    }
}
