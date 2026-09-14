import Foundation
import Testing

@testable import KiwiDesk

/// The Mac Checklist against the census (#1365). Every container
/// is a real `ForEach` over its order list, so a row moves by
/// editing the census; the guard holds that the lists and the
/// census agree, that the tree really walks them, and that each
/// row reaches its search anchor through the one `control(for:)`
/// switch keyed on its own label key.
@Suite("Mac Checklist render ↔ census parity")
struct MacChecklistCensusRenderTests {
    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .macChecklist
                    && $0.placement.container == container
            }
        )
    }

    @Test("each container renders exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in MacChecklistRowOrder.byContainer {
            #expect(
                Set(order) == censusRows(container),
                Comment(
                    rawValue:
                        "\(container) drifted from the census — "
                        + "a row moves by editing the census, "
                        + "and the order list follows"
                )
            )
            #expect(
                order.count == Set(order).count,
                "\(container) lists a row twice"
            )
        }
    }

    @Test("the area holds only the containers it renders")
    func containersMatch() {
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .macChecklist }
                .compactMap { $0.placement.container }
        )
        #expect(
            declared == Set(MacChecklistRowOrder.byContainer.keys)
        )
        #expect(MacChecklistRowOrder.bespokeContainers.isEmpty)
    }

    /// A settings row reads a macOS setting and a habit reads
    /// none — the two containers partition `MacSetting`, so a
    /// setting nobody renders or one two rows read both red.
    @Test("the settings rows partition the macOS settings")
    func settingsRowsPartitionTheReads() {
        let settings =
            (MacChecklistRowOrder.essentialSettings
            + MacChecklistRowOrder.optionalSettings)
            .compactMap { key -> MacSetting? in
                guard case .macChecklist(let k) = key else {
                    return nil
                }
                return k.setting
            }
        #expect(Set(settings) == Set(MacSetting.allCases))
        #expect(settings.count == MacSetting.allCases.count)
        for row in MacChecklistRowOrder.habits {
            guard case .macChecklist(let key) = row else {
                Issue.record("\(row.id) is not a checklist row")
                continue
            }
            #expect(key.setting == nil, "\(key) reads a setting")
        }
    }

    /// Every rendered row's catalog control carries that row's
    /// census label key, which is what lets a census search hit
    /// resolve to the row (#1250); only the tick store has none.
    @Test("every row anchors on its own label key")
    func rowsAnchorOnTheirLabelKey() {
        for key in MacChecklistKey.allCases {
            let control = MacChecklistSection.control(for: key)
            if key == .selfTicks {
                #expect(control == nil)
                continue
            }
            #expect(
                control?.key == key.labelKey,
                "\(key) anchors on \(control?.key ?? "nothing")"
            )
            guard case .key(let label) = key.text.label else {
                Issue.record("\(key) has no static label")
                continue
            }
            #expect(label == key.labelKey)
            #expect(key.text.captionKey == key.labelKey + ".caption")
        }
    }

    /// The tree walks the order lists — the promise the other
    /// areas' `bespokeMeansNoForEach` makes in the negative.
    @Test("every container is a ForEach over its list")
    func containersWalkTheirLists() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let section = root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Sections/"
                + "MacChecklistSection.swift"
        )
        let source = SourceScan.blankingCommentsAndLiterals(
            try String(contentsOf: section, encoding: .utf8)
        )
        let squashed = source.split(
            whereSeparator: \.isWhitespace
        ).joined()
        for list in [
            "essentialSettings", "optionalSettings", "habits",
        ] {
            #expect(
                squashed.contains(
                    "MacChecklistRowOrder.\(list)"
                ),
                "\(list) is not walked"
            )
        }
        #expect(
            squashed.contains(
                "settingRows(MacChecklistRowOrder.essentialSettings)"
            )
        )
        #expect(
            squashed.contains(
                "settingRows(MacChecklistRowOrder.optionalSettings)"
            )
        )
        #expect(
            squashed.contains(
                "ForEach(Array(MacChecklistRowOrder.habits"
            )
        )
        #expect(
            squashed.contains(
                "ForEach(Array(rows.enumerated())"
            )
        )
    }
}
