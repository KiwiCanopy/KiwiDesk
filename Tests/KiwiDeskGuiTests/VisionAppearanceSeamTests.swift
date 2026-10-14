import Foundation
import Testing

/// KiwiVision's appearance switch reaches the machine through ONE
/// seam (#2103 ruling 7): its live default flips the host's
/// appearance, so both `makeTestCore` twins pin the inert one, no
/// Core file but the seam's calls the OS, and the debt is paid on
/// every way out — the toggle, a stop, the next start — since a
/// lost payment leaves the user's Mac dark with no suite red.
@Suite("KiwiVision appearance seam (#2103)")
struct VisionAppearanceSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// The OS calls, and the one file that may make them.
    private static let osCalls = [
        "SystemAppearance.setDark", "SystemAppearance.rearmAuto",
        "SystemAppearance.read", "SystemAppearance.setLegacySymbol",
        "SystemAppearance.getLegacySymbol",
    ]
    private static let seamHome = "Vision/VisionAppearance.swift"

    @Test("both test-core twins pin the inert machine")
    func twinsPinInert() throws {
        for tree in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(
                    "Tests/\(tree)/TestCore.swift"
                )
            )
            #expect(
                source.occurrences(
                    of: "core.vision.appearanceSwitch = .inert()"
                ) == 1,
                "\(tree)'s makeTestCore leaves the live switch"
            )
        }
    }

    @Test("only the seam calls the system appearance")
    func oneSeamHome() throws {
        var callers: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = Array(try SourceScan.strippedSource(at: file))
            guard
                Self.osCalls.contains(where: {
                    SourceScan.mentions($0, in: text)
                })
            else { continue }
            let path = file.standardizedFileURL.path
            let prefix = Self.core.standardizedFileURL.path + "/"
            callers.insert(String(path.dropFirst(prefix.count)))
        }
        #expect(callers == [Self.seamHome], "\(callers)")
    }

    @Test("every way in and out takes the one transition")
    func transitionIsWired() throws {
        let sites: [(file: String, after: String, needle: String)] = [
            (
                "App/KiwiCore+Vision.swift", "func setKiwiVision(",
                "retargetVisionAppearance("
            ),
            (
                "App/KiwiCore+Vision.swift",
                "func appWideLiveChanged(",
                "retargetVisionAppearance("
            ),
            (
                "App/KiwiCore.swift", "var appWideLedger",
                "appWideLiveChanged(from: oldValue.live)"
            ),
            // The plate reads the one blur door the picture reads.
            (
                "App/KiwiCore+Vision.swift", "func visionRequest(",
                "blur: kiwiVisionDrawsBlur"
            ),
            // The whole stored group, so a new plate input re-draws.
            (
                "App/KiwiCore+Vision.swift", "func appWideLiveChanged(",
                "if new.vision != old.vision { updateVision() }"
            ),
            (
                "App/KiwiCore+Lifecycle.swift", "public func stop(",
                "retargetVisionAppearance(nil)"
            ),
            (
                "App/KiwiCore+Boot.swift", "public func start(",
                "retargetVisionAppearance(nil)"
            ),
            (
                "App/KiwiCore+Bootstrap.swift",
                "func bootstrapCoreServices(",
                "vision.appearanceSwitch = .live("
            ),
        ]
        for site in sites {
            let source = try SourceScan.strippedSource(
                at: Self.core.appendingPathComponent(site.file)
            )
            let body = try #require(
                SourceScan.declarationBody(after: site.after, in: source),
                "\(site.after) is gone"
            )
            #expect(
                body.occurrences(of: site.needle) == 1,
                "\(site.after) lost \(site.needle)"
            )
        }
    }

    /// v3's active value inherits one door only while the mode is
    /// switched through `setKiwiVision` (and `stop()`'s `clear()`).
    @Test("only the one door writes KiwiVision on or off")
    func oneOnOffWriter() throws {
        var writers: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            guard text.occurrences(of: "vision.isOn =") > 0 else {
                continue
            }
            let path = file.standardizedFileURL.path
            let prefix = Self.core.standardizedFileURL.path + "/"
            writers.insert(String(path.dropFirst(prefix.count)))
        }
        #expect(writers == ["App/KiwiCore+Vision.swift"], "\(writers)")
        let manager = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Vision/VisionManager.swift"
            )
        )
        let clear = try #require(
            SourceScan.declarationBody(after: "func clear(", in: manager)
        )
        // Writes, less the stored property's own declaration.
        let writes =
            manager.occurrences(of: "isOn = ")
            - manager.occurrences(of: "var isOn = ")
        #expect(
            writes == clear.occurrences(of: "isOn = "),
            "VisionManager writes isOn outside clear()"
        )
    }

    /// A crash's debt is paid before a config can turn KiwiVision
    /// on again, or the new switch is judged against the crash's.
    @Test("start pays a leftover switch before it loads the config")
    func startPaysBeforeConfig() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent("App/KiwiCore+Boot.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(after: "public func start(", in: source)
        )
        let pay = try #require(
            body.range(of: "retargetVisionAppearance(nil)")
        )
        let load = try #require(body.range(of: "loadConfig()"))
        #expect(pay.lowerBound < load.lowerBound)
    }
}
