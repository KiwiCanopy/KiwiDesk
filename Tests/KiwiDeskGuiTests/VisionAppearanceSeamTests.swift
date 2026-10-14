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
        "SystemAppearance.read",
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
                    !SourceScan.callSites(in: text, for: $0).isEmpty
                })
            else { continue }
            let path = file.standardizedFileURL.path
            let prefix = Self.core.standardizedFileURL.path + "/"
            callers.insert(String(path.dropFirst(prefix.count)))
        }
        #expect(callers == [Self.seamHome], "\(callers)")
    }

    @Test("the debt is paid on every way out, and the seam is live")
    func paymentIsWired() throws {
        let sites: [(file: String, after: String, needle: String)] = [
            (
                "App/KiwiCore+Vision.swift", "func setKiwiVision(",
                "payVisionAppearanceDebt()"
            ),
            (
                "App/KiwiCore+Vision.swift", "func setKiwiVision(",
                "applyVisionAppearance()"
            ),
            (
                "App/KiwiCore+Lifecycle.swift", "public func stop(",
                "payVisionAppearanceDebt()"
            ),
            (
                "App/KiwiCore+Boot.swift", "public func start(",
                "payVisionAppearanceDebt()"
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
}
