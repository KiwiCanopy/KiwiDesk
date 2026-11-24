import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side on a split screen (#3572 rulings 2–5): the
/// selection opens on the shown line of the area KiwiHub opened
/// over, ↑↓ walk lines across groups with no stop on a header,
/// VoiceOver names the area on each line, and each card draws its
/// groups under their names with the unfiled line last.
@Suite("Desktops area groups (#3572)")
@MainActor
struct DesktopsAreaGroupTests {
    typealias T = DesktopsStateTests

    static func area(
        _ id: Int,
        _ lines: Range<Int>,
        here: Bool
    ) -> DesktopOverview.Area {
        DesktopOverview.Area(
            key: ScreenAreaKey(fingerprint: "Wide:3440x1440", areaID: id),
            name: id == 1 ? "Chat" : nil,
            position: id == 0 ? [.left] : [.right],
            isHere: here,
            lines: lines
        )
    }

    /// One split screen, one shown Desktop: Spaces 6 and 3 on the
    /// left (3 shown), 4 (shown) and 5 on the right, then the
    /// unfiled line.
    static func overview(hereRight: Bool) -> DesktopOverview {
        let lines = [
            T.line("6", []),
            T.line("3", [], shown: true),
            T.line("4", [T.window(1, "Mail")], shown: true),
            T.line("5", []),
            DesktopOverview.SpaceLine(
                space: nil,
                mode: nil,
                isShown: false,
                marker: nil,
                windows: [T.window(2, "Notes")],
                lastFocused: nil
            ),
        ]
        let desktop = DesktopOverview.Desktop(
            native: 1,
            label: 1,
            number: 1,
            isShown: true,
            profile: nil,
            spaces: lines,
            areas: [
                area(0, 0..<2, here: !hereRight),
                area(1, 2..<4, here: hereRight),
            ]
        )
        let screen = DesktopOverview.Screen(
            display: DisplayID(2),
            name: "Wide",
            isMain: true,
            isHere: true,
            desktops: [desktop]
        )
        return DesktopOverview(screens: [screen], yours: nil)
    }

    @Test("the selection opens on the here area's shown line")
    func opensOnTheHereArea() {
        let right = T.state(Self.overview(hereRight: true))
        #expect(right.place == DesktopsPlace(screen: 0, desktop: 0, line: 2))
        let left = T.state(Self.overview(hereRight: false))
        #expect(left.place == DesktopsPlace(screen: 0, desktop: 0, line: 1))
    }

    @Test("↑↓ walk every line across groups, unfiled last")
    func stepsAcrossGroups() {
        var state = T.state(Self.overview(hereRight: false))
        var lines: [Int] = []
        for _ in 0..<5 {
            _ = state.press(.step(1), repeated: false)
            lines.append(state.place?.line ?? -1)
        }
        #expect(lines == [2, 3, 4, 0, 1])
    }

    @Test("VoiceOver names the area on each line")
    func spokenNamesTheArea() {
        LocalizationManager.shared.select("en")
        let overview = Self.overview(hereRight: true)
        let desktop = overview.screens[0].desktops[0]
        #expect(
            DesktopsText.spoken(desktop.spaces[2], at: 2, on: desktop)
                == "Space 4, shown, Chat, Desktop 1, windows: 1"
        )
        #expect(
            DesktopsText.spoken(desktop.spaces[1], at: 1, on: desktop)
                == "Space 3, shown, Left, Desktop 1, windows: 0"
        )
        // A nameless area speaks no empty name.
        let nameless = DesktopOverview.Desktop(
            native: 1,
            label: 1,
            number: 1,
            isShown: true,
            profile: nil,
            spaces: desktop.spaces,
            areas: [
                DesktopOverview.Area(
                    key: ScreenAreaKey(fingerprint: "Wide:3440x1440"),
                    name: nil,
                    position: nil,
                    isHere: true,
                    lines: 0..<4
                )
            ]
        )
        #expect(
            DesktopsText.spoken(nameless.spaces[1], at: 1, on: nameless)
                == "Space 3, shown, Desktop 1, windows: 0"
        )
        // The unfiled line is in no area.
        #expect(
            DesktopsText.spoken(desktop.spaces[4], at: 4, on: desktop)
                == "Not in a Space yet, Desktop 1, windows: 1"
        )
    }

    @Test("a card draws each group under its name, then the rest")
    func cardDrawsTheGroups() throws {
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/DesktopCardView.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.contains(
                "ForEach(desktop.areas.indices,id:\\.self){indexin"
                    + "group(desktop.areas[index])}"
                    + "ForEach(loose,id:\\.self){line($0).id(lineID($0))}"
            )
        )
        #expect(
            source.contains(
                "desktop.spaces.indices.filter{desktop.area(of:$0)==nil}"
            )
        )
        // The header is spoken on the group, never on its own.
        #expect(
            source.contains(
                ".frame(height:DesktopsGeometry.areaHeight)"
                    + ".accessibilityHidden(true)"
            )
        )
        #expect(
            source.contains(
                ".accessibilityElement(children:.contain)"
                    + ".accessibilityLabel(DesktopsText.area(area)??\"\")"
            )
        )
        // A title click lands where the start does.
        #expect(source.contains("line:desktop.landingLine"))
    }

    @Test("no screen says here; main stays")
    func hereCaptionDropped() throws {
        let source = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/DesktopsSideView.swift"
                )
        )
        #expect(!source.contains("isHere"))
        #expect(source.contains("DesktopsText.main"))
    }
}
