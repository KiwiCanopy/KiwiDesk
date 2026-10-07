import Foundation
import Testing

@testable import KiwiDesk

/// What a fixture cannot see: the close, the bootstrap and the
/// focus statement reaching the trail (#2038).
@Suite("What's new trail wiring (#2038)")
struct WhatsNewTrailWiringTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static func body(
        of declaration: String,
        in file: String
    ) throws -> String {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: gui.appendingPathComponent(file),
                encoding: .utf8
            )
        )
        return try #require(
            SourceScan.declarationBody(after: declaration, in: source)
        )
    }

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the Settings window's close ends the trail")
    func settingsCloseReachesTheModel() throws {
        let body = try Self.body(
            of: "func windowWillClose(",
            in: "Settings/SettingsWindowController.swift"
        )
        #expect(body.contains("model.settingsClosed()"))
    }

    @Test("bootstrap wires the trail once, both halves")
    func bootstrapWiresTheTrail() throws {
        let launch = try Self.body(
            of: "func applicationDidFinishLaunching(",
            in: "AppDelegate.swift"
        )
        #expect(launch.contains("wireWhatsNewTrail()"))
        let wire = try Self.body(
            of: "func wireWhatsNewTrail(",
            in: "AppDelegate+WhatsNew.swift"
        )
        #expect(wire.contains("whatsNew.showsInSettings = {"))
        #expect(wire.contains("dashboard.follow(trail)"))
        #expect(wire.contains("whatsNew.endsTrail = {"))
        #expect(wire.contains("endWhatsNewTrail()"))
        let offer = try Self.body(
            of: "func offerWhatsNew(",
            in: "AppDelegate+WhatsNew.swift"
        )
        #expect(!offer.contains("showsInSettings"))
    }

    @Test("the updater tells What's new when an update window is up")
    func updaterWiresTheSlot() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: Self.gui.appendingPathComponent(
                    "Updates/AppUpdater.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(
            Self.squashed(source).contains(
                "whatsNew?.updateOfferOpen={[driver]in"
                    + "driver.current?.isOffer??false}"
            )
        )
    }

    /// The shell outlives the banner (#996) and the statement asks
    /// the recorded input source (#991).
    @Test("the shell states the trail's focus, gated on the input source")
    func shellStatesTrailFocus() throws {
        let source = Self.squashed(
            SourceScan.stripComments(
                try String(
                    contentsOf: Self.gui.appendingPathComponent(
                        "Settings/SettingsView.swift"
                    ),
                    encoding: .utf8
                )
            )
        )
        #expect(
            source.contains(
                ".onChange(of:model.nav.trailFocusRequest){_,_in"
                    + "ifmodel.destination!=nil,"
                    + "model.nav.navigationMovesFocus{"
                    + "contentFocused=true}}"
            )
        )
    }

    /// Every outside landing takes `land(on:)`: across the window
    /// controller and the model, `pendingReveal =` is written
    /// once, inside that door.
    @Test("land(on:) is the one writer of pendingReveal")
    func oneRevealWriter() throws {
        let settings = Self.gui.appendingPathComponent("Settings")
        let files = try SourceScan.swiftSources(under: settings).filter {
            $0.lastPathComponent == "SettingsWindowController.swift"
                || $0.lastPathComponent.hasPrefix("SettingsModel")
        }
        #expect(files.count > 10)
        var writers: [String] = []
        for file in files {
            let source = Self.squashed(
                SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
            )
            let count =
                source.components(separatedBy: "pendingReveal=")
                .count - 1
            writers += Array(repeating: file.lastPathComponent, count: count)
        }
        #expect(writers == ["SettingsModel+WhatsNewTrail.swift"])
        let door = try Self.body(
            of: "func land(on anchor: SettingsAnchor) {",
            in: "Settings/SettingsModel+WhatsNewTrail.swift"
        )
        #expect(Self.squashed(door).contains("nav.pendingReveal=anchor"))
        // The notice is armed every time; the reveal judges the flip.
        #expect(
            Self.squashed(door).contains(
                "nav.pendingModeNotice=anchor.destination"
            )
        )
    }

    /// The trail's in-place navigations record the input source
    /// themselves — they move no destination, so the `didSet`
    /// recording never runs for them (#991).
    @Test("the trail records the input source before its statement")
    func trailRecordsInputSource() throws {
        let body = Self.squashed(
            try Self.body(
                of: "private func stateTrailFocus() {",
                in: "Settings/SettingsModel+WhatsNewTrail.swift"
            )
        )
        let record = try #require(
            body.range(
                of: "nav.navigationMovesFocus=SettingsInputSource.movesFocus"
            )
        )
        let bump = try #require(body.range(of: "nav.trailFocusRequest+=1"))
        #expect(record.upperBound <= bump.lowerBound)
    }

    /// The reveal announces a flip on the destination it RESOLVED.
    @Test("the reveal announces the resolved destination")
    func revealAnnouncesResolved() throws {
        let source = Self.squashed(
            SourceScan.stripComments(
                try String(
                    contentsOf: Self.gui.appendingPathComponent(
                        "Settings/SettingsView+Reveal.swift"
                    ),
                    encoding: .utf8
                )
            )
        )
        #expect(
            source.contains(
                "model.noteSearchModeSwitch(resolved.destination)"
            )
        )
    }
}
