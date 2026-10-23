import Foundation
import Testing

@testable import KiwiDeskCore

/// `animations.on_peek` (#2563): off, the bars' peeks show and hide
/// at once — the list's morph snaps, outranking Reduce Motion's
/// cross-fade, and the hover peek's fade has no length.
@Suite("Peek motion switch (#2563)")
struct PeekMotionTests {
    @Test("Off snaps, outranking Reduce Motion's cross-fade")
    func offSnaps() {
        #expect(
            BarMotion.morphPlay(onPeek: true, reduceMotion: false) == .grow
        )
        #expect(
            BarMotion.morphPlay(onPeek: true, reduceMotion: true)
                == .crossFade
        )
        for reduced in [false, true] {
            #expect(
                BarMotion.morphPlay(onPeek: false, reduceMotion: reduced)
                    == .snap
            )
        }
    }

    @Test("Off, the hover peek's fade has no length")
    func offFadesNothing() {
        #expect(
            BarMotion.peekFadeDuration(true, reduceMotion: false, onPeek: true)
                == BarMotion.peekFade
        )
        #expect(
            BarMotion.peekFadeDuration(
                true,
                reduceMotion: false,
                onPeek: false
            )
                == 0
        )
    }

    @Test("The setting defaults on and round-trips as on_peek")
    func settingRoundTrips() throws {
        let absent = try JSONDecoder().decode(
            AnimationSettings.self,
            from: Data("{}".utf8)
        )
        #expect(absent.onPeek)
        var off = AnimationSettings()
        off.onPeek = false
        let data = try JSONEncoder().encode(off)
        let json =
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["on_peek"] as? Bool == false)
        #expect(
            !(try JSONDecoder().decode(AnimationSettings.self, from: data))
                .onPeek
        )
    }

    @Test("The verb writes the setting")
    @MainActor
    func verbWrites() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-on-peek-\(UUID().uuidString)")
        )
        let response = core.execute(
            "animations.set_on_peek",
            args: [.bool(false)]
        )
        #expect(response.isSuccess)
        #expect(!core.tiler.settings.animations.onPeek)
    }
}
