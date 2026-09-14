import Foundation
import Testing

@testable import KiwiDesk

/// The Mac Checklist's read (#1365): what absence means per
/// setting, how a stored value is judged, and that the live
/// reader stays behind the model's injected seam — no suite
/// reads the host's Desktop & Dock preferences.
@Suite("Mac setting read")
struct MacSettingReadTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Absence is the shipped default, and the shipped default
    /// is what the row must say — "Not yet" everywhere macOS
    /// ships the switch ON, "Set" only for Stage Manager, which
    /// ships off. The set-equality census: a new setting must
    /// join one side consciously.
    @Test("absence reads as the shipped default")
    func absenceIsTheShippedDefault() {
        let setByDefault = Set(
            MacSetting.allCases.filter {
                MacSettingRead.state(of: $0, reading: .absent)
                    == .set
            }
        )
        #expect(setByDefault == [.stageManager])
    }

    /// A stored value outranks absence both ways, and only the
    /// target ticks: the double-click row takes one string of
    /// Apple's four, every other row the `false` that means off.
    @Test("a stored value is judged against the target")
    func storedValueIsJudged() {
        for setting in MacSetting.allCases {
            #expect(
                MacSettingRead.state(
                    of: setting,
                    reading: .value(setting.target)
                ) == .set
            )
            #expect(
                MacSettingRead.state(
                    of: setting,
                    reading: .value(setting.absentValue)
                )
                    == (setting.target == setting.absentValue
                        ? .set : .notSet)
            )
        }
        #expect(
            MacSettingRead.state(
                of: .doubleClickTitle,
                reading: .value(.string("Maximize"))
            ) == .notSet
        )
        #expect(
            MacSettingRead.state(
                of: .rearrangeSpaces,
                reading: .value(.bool(true))
            ) == .notSet
        )
    }

    /// A value of a shape this build does not know is
    /// UNREADABLE, never "Not yet" — the row then falls back to
    /// the user's own tick rather than telling them a lie. That
    /// covers a value of the OTHER kind too: `defaults write`
    /// with no `-bool` stores the string "false" under a bool
    /// key, and macOS honours it (code-reviewer, 2026-09-14).
    @Test("an unknown shape is unreadable, not not-yet")
    func unknownShapeIsUnreadable() {
        for setting in MacSetting.allCases {
            #expect(
                MacSettingRead.state(of: setting, reading: .other)
                    == .unreadable
            )
            let otherKind: MacSettingValue
            switch setting.target {
            case .bool: otherKind = .string("false")
            case .string: otherKind = .bool(false)
            }
            #expect(
                MacSettingRead.state(
                    of: setting,
                    reading: .value(otherKind)
                ) == .unreadable,
                "\(setting) judged a value of the wrong kind"
            )
        }
    }

    /// The absent arm compares `absentValue` to `target`
    /// unguarded, so a table row whose two halves are of
    /// different kinds would read "Not yet" forever — the kind
    /// gate covers the value arm, this covers the table.
    @Test("absent value and target are of one kind")
    func absentAndTargetAgreeInKind() {
        for setting in MacSetting.allCases {
            #expect(
                setting.absentValue.isSameKind(as: setting.target),
                "\(setting) mixes kinds"
            )
        }
    }

    /// Every setting names a key, and the six keys are distinct
    /// within their domain — two rows reading one key would
    /// always agree, whatever the user set.
    @Test("every setting reads its own key")
    func keysAreDistinct() {
        let pairs = MacSetting.allCases.map {
            "\($0.domain ?? "-g")/\($0.key)"
        }
        #expect(Set(pairs).count == MacSetting.allCases.count)
        for setting in MacSetting.allCases {
            #expect(!setting.key.isEmpty)
        }
    }

    /// The production default is the LIVE read, `makeTestModel`
    /// injects `.absent`, and the seam takes no other production
    /// write: the mention count pins declaration + one read.
    /// `CFPreferencesCopyAppValue` stays inside the two readers
    /// that own one (`SystemShortcutEnablement` and this), so a
    /// third site reading the host lands here rather than in a
    /// suite that never asked.
    @Test("the seam defaults live and tests inject absent")
    func seamPolarity() throws {
        let model = try Self.stripped(
            "Sources/KiwiDesk/Settings/SettingsModel.swift"
        )
        #expect(
            model.contains(
                "varreadMacSetting:(MacSetting)->MacSettingRaw="
                    + "MacSettingRead.liveRead"
            )
        )
        var mentions = 0
        var liveReads = 0
        var cfReads: [String] = []
        for url in try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDesk"
            )
        ) {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            mentions +=
                text.components(separatedBy: "readMacSetting")
                .count - 1
            liveReads +=
                text.components(
                    separatedBy: "MacSettingRead.liveRead"
                ).count - 1
            if text.contains("CFPreferencesCopyAppValue(") {
                cfReads.append(url.lastPathComponent)
            }
        }
        #expect(mentions == 2)
        #expect(liveReads == 1)
        #expect(
            Set(cfReads) == [
                "SystemShortcutEnablement.swift", "MacSetting.swift",
            ]
        )
        let factory = try Self.stripped(
            "Tests/KiwiDeskGuiTests/TestModel.swift"
        )
        #expect(factory.contains("model.readMacSetting={_in.absent}"))
    }

    private static func stripped(_ path: String) throws -> String {
        let url = root.appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }
}
