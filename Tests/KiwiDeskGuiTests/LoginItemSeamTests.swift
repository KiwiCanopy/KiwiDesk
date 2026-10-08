import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Settings reaches `SMAppService` only through the
/// `SettingsModel.writeLoginItem` / `readAutoStart` seams, which
/// `makeTestModel` pins (#2092, the #565 shape): `mainApp` is the
/// CALLING process, so a live write from a test registers the
/// test helper as a login item.
///
/// Main-actor spend: two models, each awaited on its own seam;
/// the scans run off the main actor.
@Suite("Login item stays behind its seam")
struct LoginItemSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    /// Generous: the poll exits the moment the seam answers, so
    /// only a genuine hang waits this long (#344).
    private static let hangGuard: Duration = .seconds(30)

    /// Where each live touch may be spelled, and how often — the
    /// one copy of who may. `SettingsModel` holds the seams'
    /// defaults; Core's `LoginItemManager` is the one OS caller;
    /// the onboarding wiring feeds `OnboardingModel`'s closure,
    /// whose own default is a no-op.
    private static let allowed: [String: [String: Int]] = [
        "SMAppService" + ".mainApp": ["LoginItemManager.swift": 3],
        "AutoStartManager" + ".setLoginItem": [
            "SettingsModel.swift": 1
        ],
        "AutoStartManager" + ".current": ["SettingsModel.swift": 1],
        "LoginItemManager" + ".setEnabled": [
            "AutoStartManager.swift": 1,
            "AppDelegate+Onboarding.swift": 1,
        ],
    ]

    private static let status = AutoStartStatus(
        level: .off,
        unavailable: nil,
        requiresApproval: false
    )

    @MainActor
    private static func settle(
        _ busy: () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + hangGuard
        while busy(), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

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
        model.autoStart = Self.status
        model.autoStartLoaded = true
        model.setLoginItem(true, reduceMotion: true)
        #expect(model.autoStartBusy)
        try await Self.settle { model.autoStartBusy }
        #expect(written == [true])
        #expect(model.autoStart.level == .atLogin)
    }

    @MainActor
    @Test("the refresh reads through the injected seam")
    func refreshTakesTheSeam() async throws {
        let model = makeTestModel()
        var reads = 0
        model.readAutoStart = {
            reads += 1
            return AutoStartStatus(
                level: .atLoginWithAutoRestart,
                unavailable: nil,
                requiresApproval: false
            )
        }
        model.refreshAutoStart()
        try await Self.settle { !model.autoStartLoaded }
        #expect(reads == 1)
        #expect(model.autoStart.level == .atLoginWithAutoRestart)
    }

    @Test("every live touch is spelled only where allowed")
    func liveTouchesStayHome() throws {
        let testTrees = SourceScan.targetTrees(
            under: Self.root.appendingPathComponent("Tests")
        )
        for (needle, homes) in Self.allowed {
            let sites = try Self.productionTrees.flatMap {
                try SourceScan.identifierSites(of: needle, under: $0)
            }
            var found: [String: Int] = [:]
            for site in sites {
                found[site.file.lastPathComponent, default: 0] += 1
            }
            #expect(found == homes, "\(needle) spelled at \(found)")
            // A pin spelled as the live touch is no pin.
            let inTests = try testTrees.flatMap {
                try SourceScan.identifierSites(of: needle, under: $0)
            }
            #expect(
                inTests.isEmpty,
                "\(needle) in tests: \(inTests.map(\.site))"
            )
        }
    }

    @Test("makeTestModel pins both seams")
    func factoryPinsTheSeams() throws {
        let file = Self.root.appendingPathComponent(
            "Tests/KiwiDeskGuiTests/TestModel.swift"
        )
        let source = try SourceScan.strippedSource(at: file)
        for pin in ["writeLoginItem", "readAutoStart"] {
            #expect(
                source.occurrences(of: "model.\(pin) =") == 1,
                "makeTestModel pins \(pin) once"
            )
        }
    }
}
