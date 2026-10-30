import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A row on another screen than KiwiHub's (#2792 ▸ Ruling): the
/// screen is named first on the row, last when spoken, and is the
/// one part a narrow row shortens.
@Suite("Jump row on another screen")
@MainActor
struct JumpRowScreenTests {
    private let dell = ScreenLabel(name: "DELL U2723")

    private func entry(
        space: SpaceID?,
        status: JumpEntry.Status,
        screen: ScreenLabel?
    ) -> JumpEntry {
        JumpEntry(
            target: .window(WindowID(1)),
            pid: 1,
            app: "Mail",
            title: "Inbox",
            space: space,
            spaceIcon: nil,
            status: status,
            screen: screen
        )
    }

    @Test("each row state reads screen first")
    func placeText() {
        LocalizationManager.shared.select("en")
        func text(_ space: SpaceID?, _ status: JumpEntry.Status) -> String? {
            JumpRowText.place(
                of: entry(space: space, status: status, screen: dell)
            )?.text
        }
        #expect(text("work", .shown) == "work · DELL U2723")
        #expect(
            text("work", .away(desktop: 1)) == "work · DELL U2723 Desktop 1"
        )
        #expect(text(nil, .away(desktop: 2)) == "DELL U2723 Desktop 2")
        #expect(text("work", .away(desktop: nil)) == "work · DELL U2723")
        #expect(text(nil, .away(desktop: nil)) == nil)
        // KiwiHub's own screen, or one screen: unchanged.
        #expect(
            JumpRowText.place(
                of: entry(space: "work", status: .shown, screen: nil)
            )?.text == "work"
        )
    }

    @Test("the screen's name is the run a narrow row shortens")
    func screenRun() throws {
        LocalizationManager.shared.select("en")
        let place = try #require(
            JumpRowText.place(
                of: entry(
                    space: "work",
                    status: .away(desktop: 3),
                    screen: dell
                )
            )
        )
        #expect(
            place.screen
                == JumpRowText.ScreenRun(
                    lead: "work · ",
                    name: "DELL U2723",
                    trail: " Desktop 3"
                )
        )
    }

    @Test("VoiceOver names the screen last")
    func spoken() {
        LocalizationManager.shared.select("en")
        func said(_ space: SpaceID?, _ status: JumpEntry.Status) -> String {
            JumpRowText.spoken(
                entry(space: space, status: status, screen: dell)
            )
        }
        #expect(said("work", .shown) == "Mail, Inbox, work on DELL U2723")
        #expect(
            said("work", .away(desktop: 1))
                == "Mail, Inbox, work, Desktop 1 on DELL U2723"
        )
        #expect(
            said(nil, .away(desktop: 2))
                == "Mail, Inbox, Desktop 2 on DELL U2723"
        )
    }

    @Test("twin screens read by place")
    func twins() {
        LocalizationManager.shared.select("en")
        #expect(
            ScreenLabel(name: "DELL", twinPlace: 0).displayName
                == "Main screen"
        )
        #expect(
            ScreenLabel(name: "DELL", twinPlace: 1).displayName
                == "Screen 2"
        )
        #expect(ScreenLabel(name: "DELL").displayName == "DELL")
    }

    @Test("the switch plate speaks its screen")
    func plateSpoken() {
        LocalizationManager.shared.select("en")
        let cue = DesktopSwitchCue(
            display: DisplayID(2),
            position: 1,
            count: 3,
            loadedProfile: nil,
            screen: dell
        )
        #expect(
            CuePlateModel.spoken(.desktop(cue))
                == "Desktop 1 of 3 on DELL U2723"
        )
        let lone = DesktopSwitchCue(
            display: DisplayID(1),
            position: 2,
            count: 4,
            loadedProfile: nil
        )
        #expect(CuePlateModel.spoken(.desktop(lone)) == "Desktop 2 of 4")
    }
}

/// A Desktop shortcut row keeps its global title and says where
/// that number lands now (#2792 ▸ the shortcut rows comment).
@Suite("Desktop shortcut row landing")
@MainActor
struct DesktopShortcutLandingTests {
    @Test("a row names its landing, or that no Desktop has it")
    func detail() {
        LocalizationManager.shared.select("en")
        let landings = [
            3: DesktopLanding(screen: ScreenLabel(name: "DELL"), number: 1)
        ]
        let rows = KeybindingCatalog.goToDesktop(
            [3, 9],
            absent: [9],
            landings: landings
        )
        #expect(rows[0].resolvedLabel == "Go to Desktop 3")
        #expect(rows[0].detail?() == "DELL · Desktop 1")
        #expect(rows[1].detail?() == "Not present right now")
        // One screen: the number says it all.
        let lone = KeybindingCatalog.goToDesktop([3, 9], absent: [9])
        #expect(lone.allSatisfy { $0.detail == nil })
    }
}

/// A Desktop row that names its landing keeps its own line: a fold
/// would drop it (#2792).
@Suite("Desktop landing rows never fold")
@MainActor
struct DesktopLandingFoldTests {
    @Test("a landing row is not plain")
    func landingIsNotPlain() {
        let landed = KeybindingCatalog.goToDesktop(
            [1],
            landings: [
                1: DesktopLanding(screen: ScreenLabel(name: "A"), number: 1)
            ]
        )[0]
        let lone = KeybindingCatalog.goToDesktop([1])[0]
        func tag(_ command: NavCommand) -> ShortcutFold.Tag? {
            ShortcutFold.tag(
                for: command,
                at: .init(family: .goToDesktop, position: 1),
                combo: KeyCombo.parse("control+option+shift+command+1"),
                rendered: "⌃⌥⇧⌘1"
            )
        }
        #expect(tag(lone)?.plain == true)
        #expect(tag(landed)?.plain == false)
    }
}
