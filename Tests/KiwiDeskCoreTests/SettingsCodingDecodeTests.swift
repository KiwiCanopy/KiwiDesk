import Foundation
import Testing

@testable import KiwiDeskCore

/// The DECODE half of the profile JSON contract, split from
/// `SettingsCodingTests` at §2.1's ceiling. That suite pins the
/// encoded SHAPE — which keys exist, in which groups; these pin
/// what a decode does with a file: a full round trip, and what
/// a PARTIAL one falls back to, which is the half a hand-edited
/// or older profile actually exercises.
@Suite("Settings JSON decoding")
struct SettingsCodingDecodeTests {
    @Test("Round-trip preserves every setting")
    func roundTrip() throws {
        var settings = TilingSettings()
        settings.bsp.splitRatioH = 0.7
        settings.bsp.splitRatioV = 0.3
        settings.scrolling.slotSize = .points(400)
        settings.stack.masterCount = 2
        settings.stack.masterOrientation = .vertical
        settings.stack.stackPosition = .top
        settings.grid.rows = 4
        settings.grid.autoSize = true
        settings.monocle.wrapFocus = false
        settings.monocle.hideStyle = .park
        settings.track.axis = .horizontal
        settings.track.autoTracks = false
        settings.track.limit = 3
        settings.track.newWindow = .focusedTrack
        settings.track.wrapFocus = true
        settings.minWindowSize = 200
        settings.swapSkipsCascade = false
        settings.floatNudge = false
        settings.floatScaleOnDisplayChange = false
        settings.resizeStep = 75
        settings.refusalSound = true
        settings.shortcutPanelLiquidGlass = true
        settings.dragGhost.enabled = false
        settings.dragDropZone.fillColor = "#11223344"
        settings.dragCornerRadius = 22
        settings.borderStyle.enabled = false
        settings.borderStyle.width = 6
        settings.borderStyle.focusedColor = "#010203"
        settings.borderStyle.unfocusedEnabled = true
        settings.borderStyle.unfocusedColor = "#04050607"
        settings.borderStyle.cornerStyle = .square
        settings.borderStyle.glow = true
        settings.stickyStyle.mark = false
        settings.stickyStyle.color = "#4E9F3D"
        settings.floatingStyle.color = "#E8A33D"
        settings.spaceBarStyle.stickyBadge = false
        settings.gapsOverride[SpaceID(2)] = .uniform(4)
        settings.placementOverride[SpaceID("mail")] = .last
        settings.animations.onSpaceChange = true
        settings.animations.onScrolling = false
        settings.animations.onWindowResize = false
        settings.animations.onWindowSwap = false
        settings.animations.onRelayout = false
        settings.animations.durationMS = 400
        settings.animations.scrollDurationMS = 180
        settings.mouse.followsFocus = true
        settings.quitGridTargetDepth = 12
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded == settings)
    }

    @Test("quit.grid_target_depth clamps into range on decode")
    func targetDepthDecodeClamp() throws {
        // A hand-edited profile can't smuggle a value past the
        // range the command and GUI enforce (#281 review).
        for (raw, expected) in [(999, 20), (0, 1), (-7, 1)] {
            let json = Data(
                #"{"quit":{"grid_target_depth":\#(raw)}}"#
                    .utf8
            )
            let decoded = try JSONDecoder().decode(
                TilingSettings.self,
                from: json
            )
            #expect(decoded.quitGridTargetDepth == expected)
        }
    }

    @Test("A partial animations object keeps the other default")
    func partialAnimationsDecode() throws {
        let json = #"{"animations":{"on_space_change":true}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.animations.onSpaceChange)
        // on_scrolling absent — keeps its `true` default.
        #expect(decoded.animations.onScrolling)
        // Duration knobs absent — keep their 150 ms defaults.
        #expect(decoded.animations.durationMS == 150)
        #expect(decoded.animations.scrollDurationMS == 150)
    }

    @Test("Missing keys fall back to defaults")
    func defaults() throws {
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data("{}".utf8)
        )
        #expect(decoded == TilingSettings())
    }
}
