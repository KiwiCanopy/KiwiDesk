import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A lens's Auto-open (#3122): the wirings no fixture reaches, each
/// pinned by exact count to its file, and the notice's renderer.
/// The behaviour is `KiwiVisionAutoOpenTests`' and
/// `KiwiVisionAutoOpenFocusTests`'.
@Suite("A lens's Auto-open stays wired (#3122)")
struct KiwiVisionAutoOpenWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func flat(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: root.appendingPathComponent(path)
        ).filter { !$0.isWhitespace }
    }

    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// needle (whitespace dropped) → the one file, and how often.
    private static let wirings: [(String, String, Int)] = [
        // The two user doors decide; `setVision` never does.
        ("openLensApps(lens)", "App/KiwiCore+VisionLens.swift", 2),
        ("openLensApps(", "App/KiwiCore+Vision.swift", 0),
        // A config load opens nothing.
        ("vision.configLoading=true", "App/KiwiCore+Config.swift", 1),
        // The fold's quiet arrival, mirrored ahead of the apply.
        (
            "state.arrivesQuietly=launchFollow.opensQuietly(",
            "App/KiwiCore+Events.swift", 1
        ),
        // The one focus move, claimed ahead of the launch follow.
        (
            "ifclaimQuietOpen(arrived:window){returnnil}",
            "App/KiwiCore+LaunchFollow.swift", 1
        ),
        // A quiet activation owes no follow.
        (
            "guard!launchFollow.opensQuietly(bundleID.lowercased(),at:now)",
            "App/KiwiCore+LaunchFollow.swift", 1
        ),
        // The notice crosses as structure, and the pill falls back
        // to the screen.
        ("vision.onNotice(notice)", "App/KiwiCore+VisionReach.swift", 1),
        ("borders.flashScreenPill(", "App/KiwiCore+VisionReach.swift", 1),
        // The background mode reaches the open's configuration.
        (
            "config.activates=mode!=.background",
            "Commands/KiwiCore+LaunchRestore.swift", 1
        ),
    ]

    @Test("Core's wirings sit where they are owed")
    func coreWirings() throws {
        for (needle, file, expected) in Self.wirings {
            let text = try Self.flat("Sources/KiwiDeskCore/" + file)
            #expect(!text.isEmpty)
            #expect(
                Self.count(needle, in: text) == expected,
                "\(needle) in \(file)"
            )
        }
    }

    @Test("the fold grants a quiet arrival no focus")
    func foldReadsTheMirror() throws {
        let fold = try Self.flat(
            "Sources/KiwiDeskCore/State/StateCoordinator+WindowCreated.swift"
        )
        #expect(Self.count("letquiet=arrivesQuietly", in: fold) == 1)
        // Nor a rule follow.
        #expect(
            Self.count("claim!=.awaited(window.id),!quiet", in: fold) == 1
        )
        #expect(
            Self.count(
                "guardwindows[window.id]?.isTransientOverlay!=true,!quiet",
                in: fold
            ) == 1
        )
    }

    @Test("the delegate announces each notice")
    func delegateAnnounces() throws {
        let text = try Self.flat(
            "Sources/KiwiDesk/AppDelegate+KiwiVision.swift"
        )
        #expect(Self.count("core.vision.onNotice={noticein", in: text) == 1)
        #expect(
            Self.count(".announcement:Self.announcement(notice)", in: text)
                == 1
        )
    }

    @Test("each Apps row draws the switch and removes through Core")
    func appsRowWiring() throws {
        let card = try Self.flat(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionLensAppsCard.swift"
        )
        #expect(
            Self.count(
                "KiwiVisionLensAutoOpenToggle(lens:lens,app:app)",
                in: card
            ) == 1
        )
        #expect(Self.count("$0.setOpensApp(app,on)", in: card) == 1)
        #expect(Self.count("$0.removeApp(app)", in: card) == 1)
        #expect(Self.count("$0.titles[app]=nil", in: card) == 0)
        let toggle = try Self.flat(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionLensAutoOpen.swift"
        )
        for needle in [
            "letblock=lens.autoOpenBlock(app)",
            ".disabled(block!=nil)",
            ".toggleStyle(.switch)",
            ".controlSize(.small)",
            ".accessibilityHint(",
        ] {
            #expect(Self.count(needle, in: toggle) == 1, "\(needle)")
        }
    }

    @Test("a notice reads as the pill's sentence")
    @MainActor
    func renderer() {
        LocalizationManager.shared.select("en")
        #expect(
            AppDelegate.announcement(.noMemberOpen(lens: "Writing"))
                == "Writing is on: none of its apps is open."
        )
        #expect(
            AppDelegate.announcement(.notInstalled(app: "com.x.y"))
                == "com.x.y is not installed."
        )
    }

    @Test("a greyed switch gives its reason")
    @MainActor
    func greyedReasons() {
        LocalizationManager.shared.select("en")
        let titled = KiwiVisionLensAutoOpenWords.blocked(.titled)
        let unnamed = KiwiVisionLensAutoOpenWords.blocked(.noBundleID)
        #expect(!titled.isEmpty)
        #expect(!unnamed.isEmpty)
        #expect(titled != unnamed)
    }
}
