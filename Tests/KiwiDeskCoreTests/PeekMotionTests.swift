import AppKit
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

    /// The morph reads the switch live: off, it snaps the list in
    /// and the pill out at once, and lands with no wait. Writes the
    /// process-wide pace synchronously and puts it back.
    @Test("Off, the morph snaps and lands at once")
    @MainActor
    func morphReadsTheSwitch() {
        let was = BarMotion.peekMotion
        defer { BarMotion.peekMotion = was }
        BarMotion.peekMotion = false
        let panel = NSPanel()
        let anchor = NSPanel()
        panel.alphaValue = 0
        let parts = BarPeekMorphParts(
            stage: CALayer(),
            rows: CALayer(),
            markInk: CALayer(),
            listInk: CALayer()
        )
        let span = BarMotion.playMorph(
            parts,
            panel: panel,
            anchor: anchor,
            pill: CGRect(x: 0, y: 0, width: 18, height: 18),
            pillRadius: 9,
            listRadius: 11,
            opening: true
        )
        #expect(span == 0)
        #expect(panel.alphaValue == 1)
        #expect(anchor.alphaValue == 0)
        #expect(parts.stage.animationKeys() == nil)
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
        // The bar pass writes the process-wide pace; put it back.
        let was = BarMotion.peekMotion
        defer { BarMotion.peekMotion = was }
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
        #expect(!BarMotion.peekMotion)
    }

    /// A bar item's list fades out as it shrinks to its seed, so no
    /// plate rests while the spring settles (#2571, device); the
    /// overflow mark's shrinks back into its pill whole.
    @Test("A bar list's close fades its stage; the pill's does not")
    @MainActor
    func barListCloseFades() {
        let was = (BarMotion.peekMotion, BarMotion.reducedOverride)
        defer {
            BarMotion.peekMotion = was.0
            BarMotion.reducedOverride = was.1
        }
        BarMotion.peekMotion = true
        BarMotion.reducedOverride = false
        for fadesOut in [true, false] {
            let parts = BarPeekMorphParts(
                stage: CALayer(),
                rows: CALayer(),
                markInk: CALayer(),
                listInk: CALayer()
            )
            parts.stage.bounds = CGRect(x: 0, y: 0, width: 180, height: 120)
            BarMotion.playMorph(
                parts,
                panel: NSPanel(),
                anchor: nil,
                pill: CGRect(x: 80, y: 102, width: 24, height: 18),
                pillRadius: 9,
                listRadius: 11,
                opening: false,
                fadesOut: fadesOut
            )
            let keys = parts.stage.animationKeys() ?? []
            #expect(
                keys.contains(BarMotion.morphFadeKey) == fadesOut,
                "fadesOut \(fadesOut)"
            )
            BarMotion.endMorph(parts)
            #expect(parts.stage.animationKeys() == nil)
        }
    }
}
