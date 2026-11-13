import Foundation
import Testing

@testable import KiwiDeskCore

/// The speed preset (#3238, #3254): each speed writes its table and
/// reads back as itself, lengths no table holds read as Custom, and
/// Off is a flag beside the lengths, so leaving it restores the pace.
@Suite("Animation speed preset (#3238)")
struct AnimationPacePresetTests {
    private static let speeds = AnimationPacePreset.allCases.filter {
        $0 != .off
    }

    @Test("each speed round-trips", arguments: speeds)
    func speedRoundTrips(_ speed: AnimationPacePreset) throws {
        var pace = AppWideSettings()
        pace.applyPace(.slow == speed ? .fast : .slow)
        #expect(AnimationPacePreset.current(of: pace) != speed)
        pace.applyPace(speed)
        #expect(pace.paceTable == speed.table)
        #expect(AnimationPacePreset.current(of: pace) == speed)
        #expect(!pace.animationReduceMotion)
    }

    /// The shipped defaults are Medium's table, so a fresh install
    /// reads Medium rather than Custom (#3254).
    @Test("the defaults read as Medium")
    func defaultsReadMedium() {
        let pace = AppWideSettings()
        #expect(AnimationPacePreset.current(of: pace) == .medium)
        #expect(
            AnimationPacePreset.medium.table == AnimationPacePreset.shipped
        )
    }

    /// The speeds run slowest moving step first, each window length
    /// shorter than the one before (#3254 ▸ Ruling).
    @Test("the speeds step evenly, slowest first")
    func speedsStepEvenly() throws {
        let windows = try Self.speeds.map { try #require($0.table).window }
        #expect(windows.count == 4)
        let steps = zip(windows, windows.dropFirst()).map { $0 - $1 }
        #expect(Set(steps).count == 1)
        #expect(steps.first.map { $0 > 0 } == true)
    }

    /// One length off every table reads as Custom, and a speed
    /// picked after it writes all six again.
    @Test("a length no table holds reads as Custom")
    func customReadsNone() {
        var pace = AppWideSettings()
        pace.applyPace(.fast)
        pace.spaceSlideDuration = 450
        #expect(AnimationPacePreset.current(of: pace) == nil)
        pace.applyPace(.fast)
        #expect(AnimationPacePreset.current(of: pace) == .fast)
    }

    /// Off sets the flag alone; clearing it gives back the exact
    /// lengths, Custom ones included.
    @Test("Off leaves every length unchanged")
    func offKeepsLengths() {
        var pace = AppWideSettings()
        pace.applyPace(.slow)
        pace.animationScrollDurationMS = 350
        let before = pace.paceTable
        pace.applyPace(.off)
        #expect(pace.animationReduceMotion)
        #expect(pace.paceTable == before)
        #expect(AnimationPacePreset.current(of: pace) == .off)
        pace.animationReduceMotion = false
        #expect(pace.paceTable == before)
        #expect(AnimationPacePreset.current(of: pace) == nil)
    }

    /// Each table sits inside the bands Core clamps to, so a pick
    /// never stores a value the decoder would move.
    @Test("every table sits inside its bands", arguments: speeds)
    func tablesInsideBands(_ speed: AnimationPacePreset) throws {
        let table = try #require(speed.table)
        #expect(AnimationSettings.durationBand.contains(table.window))
        #expect(AnimationSettings.durationBand.contains(table.scroll))
        #expect(
            AnimationSettings.expandDurationBand.contains(table.expand)
        )
        #expect(
            AnimationSettings.revealDurationBand.contains(table.reveal)
        )
        #expect(
            AppWideSettings.spaceSlideDurationRange.contains(table.slide)
        )
        #expect(AppWideSettings.visionFadeRange.contains(table.fade))
    }

    /// Off plays no expand or reveal, whatever the profile's switch.
    @Test("Off stops the bars' expand and reveal")
    func offStopsBarMotion() {
        var pace = AppWideSettings()
        let animations = AnimationSettings()
        #expect(animations.expandSeconds(at: pace) > 0)
        #expect(animations.revealSeconds(at: pace) > 0)
        pace.applyPace(.off)
        #expect(animations.expandSeconds(at: pace) == 0)
        #expect(animations.revealSeconds(at: pace) == 0)
    }

    /// The flag is stored in the app-wide `animations` group.
    @Test("the flag round-trips through gui.json")
    func flagRoundTrips() throws {
        var config = GuiConfig()
        var pace = AppWideSettings()
        pace.applyPace(.off)
        config.appWide = pace
        let data = try JSONEncoder().encode(config)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"reduce_motion\""))
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.animationReduceMotion == true)
    }
}
