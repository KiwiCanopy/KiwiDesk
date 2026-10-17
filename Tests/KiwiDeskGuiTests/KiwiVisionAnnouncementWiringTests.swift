import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// VoiceOver hears every KiwiVision change, whichever door made it
/// (#2103). The wiring lives in `AppDelegate+KiwiVision`, which no
/// test constructs, so it is pinned where it lives.
@Suite("KiwiVision announcement is wired")
struct KiwiVisionAnnouncementWiringTests {
    @Test("the app delegate wires the announcement and the page")
    func delegateWiresTheAnnouncement() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let text = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate+KiwiVision.swift"
            )
        ).filter { !$0.isWhitespace }
        for needle in [
            "core.vision.onChange={[weakself]",
            "core.onAppWideChange={[weakself]in",
            // A profile switch moves which lenses reach (#2103).
            "core.vision.onReachChange={[weakself]in"
                + "self?.visionReadersChanged()}",
            ".announcement:Self.announcement(on:on,cause:cause)",
            "notification:.announcementRequested",
        ] {
            #expect(text.contains(needle), "missing \(needle)")
        }
        let delegate = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate.swift"
            )
        )
        #expect(delegate.contains("wireKiwiVision()"))
    }

    /// Ruling 16's pill: the one writer draws a cause's cue before
    /// it is heard, and the live profile's every change reaches the
    /// re-judge. No fixture sees a pill draw, so the wiring is
    /// pinned where it lives.
    @Test("a cause draws its pill, and a profile change re-judges")
    func coreCueWiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        func flat(_ path: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            ).filter { !$0.isWhitespace }
        }
        let vision = try flat(
            "Sources/KiwiDeskCore/App/KiwiCore+Vision.swift"
        )
        #expect(
            vision.contains(
                "ifletcause{cueVisionOff(cause)}"
                    + "vision.onChange(next,cause)"
            )
        )
        let boot = try flat(
            "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
        )
        #expect(
            boot.contains(
                "profiles.onActiveChange={[weakself]in"
                    + "self?.liveProfileChanged()}"
            )
        )
    }

    /// Ruling 16: an off the user did not ask for says why, in the
    /// sentence the pill draws; an asked one says on or off.
    @Test("an off by reach announces its reason")
    @MainActor
    func reachAnnouncement() {
        LocalizationManager.shared.select("en")
        #expect(
            AppDelegate.announcement(
                on: false,
                cause: .outOfReach(lens: "Writing", profile: "Studio")
            ) == "Writing is off: it does not reach Studio."
        )
        #expect(
            AppDelegate.announcement(on: false, cause: nil)
                == "KiwiVision off"
        )
        #expect(
            AppDelegate.announcement(on: true, cause: nil)
                == "KiwiVision on"
        )
    }
}
