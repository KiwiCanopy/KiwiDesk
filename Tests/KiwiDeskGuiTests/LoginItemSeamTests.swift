import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The login-item write reaches `SMAppService` only through the
/// `SettingsModel.writeLoginItem` seam (#2092). `mainApp`
/// registers the CALLING process, so a setter that acted from a
/// test registered Xcode's `swiftpm-testing-helper` as a login
/// item on every GUI run — while `SMAppService` had no hit in
/// `Tests/`, the #565 shape. A sibling of `MachineTouchTests`,
/// which sits at the §2.1 ceiling.
///
/// Main-actor spend: one model, one setter drive awaited on its
/// own write; the scans run off the main actor.
@Suite("Login item write stays behind its seam")
struct LoginItemSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    /// Generous: the poll exits the moment the write lands, so
    /// only a genuine hang waits this long (#344).
    private static let writeHangGuard: Duration = .seconds(30)

    /// Where each live write may be spelled, and why — the one
    /// copy of who may. The model's seam default is the only
    /// route from Settings; Core's own call is the seam's live
    /// body; the onboarding wiring feeds `OnboardingModel`'s
    /// closure, whose default is a no-op.
    private static let allowed: [String: String] = [
        "AutoStartManager" + ".setLoginItem":
            "SettingsModel.swift",
        "LoginItemManager" + ".setEnabled":
            "AutoStartManager.swift AppDelegate+Onboarding.swift",
    ]

    @MainActor
    @Test("the setter writes through the injected seam")
    func setterTakesTheSeam() async throws {
        let model = makeTestModel()
        var written: [Bool] = []
        model.writeLoginItem = { enabled in
            written.append(enabled)
            return AutoStartStatus(
                level: enabled ? .atLogin : .off,
                unavailable: nil,
                requiresApproval: false
            )
        }
        model.autoStart = AutoStartStatus(
            level: .off,
            unavailable: nil,
            requiresApproval: false
        )
        model.autoStartLoaded = true
        model.setLoginItem(true, reduceMotion: true)
        #expect(model.autoStartBusy)
        let clock = ContinuousClock()
        let deadline = clock.now + Self.writeHangGuard
        while model.autoStartBusy, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(written == [true])
        #expect(model.autoStart.level == .atLogin)
    }

    @Test("every live write is spelled only where allowed")
    func liveWritesStayHome() throws {
        for (needle, homes) in Self.allowed {
            let files = homes.split(separator: " ").map(String.init)
            let sites = try Self.productionTrees.flatMap {
                try SourceScan.identifierSites(of: needle, under: $0)
            }
            let found = Set(sites.map(\.file.lastPathComponent))
            #expect(
                found == Set(files),
                "\(needle) spelled in \(found.sorted())"
            )
            #expect(
                sites.count == files.count,
                "\(needle): a second spelling inside a home"
            )
            // A pin spelled as the live write is no pin.
            let inTests = try SourceScan.targetTrees(
                under: Self.root.appendingPathComponent("Tests")
            ).flatMap {
                try SourceScan.identifierSites(of: needle, under: $0)
            }
            #expect(
                inTests.isEmpty,
                "\(needle) in tests: \(inTests.map(\.site))"
            )
        }
    }

    @Test("makeTestModel pins the write inert")
    func factoryPinsTheWrite() throws {
        let file = Self.root.appendingPathComponent(
            "Tests/KiwiDeskGuiTests/TestModel.swift"
        )
        let source = try SourceScan.strippedSource(at: file)
        #expect(source.occurrences(of: "model.writeLoginItem =") == 1)
    }
}
