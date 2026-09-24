import Combine
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// "Install updates automatically" (#1542): the row shows Sparkle's
/// value, not its own guess, and greys with a reason where Sparkle
/// refuses it.
@MainActor
@Suite("Install updates automatically (#1542)")
struct AutoInstallSettingTests {
    private final class Sparkle {
        var on: Bool
        var accepts = true
        var allowed = true
        let changed = PassthroughSubject<Void, Never>()
        init(on: Bool) { self.on = on }
    }

    private func setting(_ sparkle: Sparkle) -> AutoInstallSetting {
        AutoInstallSetting(
            read: { (sparkle.on, sparkle.allowed ? nil : .checksOff) },
            write: { if sparkle.accepts { sparkle.on = $0 } },
            changes: sparkle.changed.eraseToAnyPublisher()
        )
    }

    /// A row that started from its own default would read off.
    @Test("it starts from Sparkle's value")
    func startsFromSparkle() {
        #expect(setting(Sparkle(on: true)).isOn)
    }

    /// Written through and read back: a refused write shows as
    /// refused rather than as the row's own wish.
    @Test("a write reads back what Sparkle kept")
    func writeReadsBack() {
        let sparkle = Sparkle(on: false)
        let setting = setting(sparkle)
        setting.set(true)
        #expect(setting.isOn)
        sparkle.accepts = false
        setting.set(false)
        #expect(setting.isOn)
    }

    /// Sparkle's own KVO — including an outside `defaults write` —
    /// reaches an open pane.
    @Test("an outside change reaches the row")
    func outsideChange() {
        let sparkle = Sparkle(on: false)
        let setting = setting(sparkle)
        sparkle.on = true
        sparkle.changed.send()
        #expect(setting.isOn)
    }

    /// Where Sparkle refuses, the row greys with the resolver's
    /// reason and a press writes nothing.
    @Test("refused, it greys with a reason and writes nothing")
    func refusedGreys() {
        let sparkle = Sparkle(on: false)
        sparkle.allowed = false
        let setting = setting(sparkle)
        setting.set(true)
        #expect(!sparkle.on)
        let gates = GeneralGates(
            autoStart: AutoStartStatus(
                level: .off,
                unavailable: nil,
                requiresApproval: false
            ),
            autoInstall: setting.unavailable
        )
        #expect(
            gates.inertReason(for: .general(.installUpdatesAutomatically))
                == .automaticInstall(.checksOff)
        )
        #expect(AutoInstallSetting.inert().unavailable == .noChannel)
    }

    /// The row is mounted with the updater's own setting, and the
    /// live updater reaches Sparkle's two properties.
    @Test("the row and the updater are wired")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let general = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/GeneralSection.swift"
            )
        )
        #expect(
            general.occurrences(
                of: "AutoInstallRow(model: model, "
                    + "setting: model.updater.autoInstall)"
            ) == 1
        )
        let updater = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Updates/AppUpdater.swift"
            )
        )
        #expect(
            updater.occurrences(
                of: "updater.automaticallyDownloadsUpdates = $0"
            ) == 1
        )
        #expect(
            updater.occurrences(
                of: "updater.allowsAutomaticUpdates ? nil : .checksOff"
            ) == 1
        )
    }
}
