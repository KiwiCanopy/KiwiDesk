import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Where "What's new" surfaces (#1542): the quick-menu row and the
/// status item's mark in #1013's shape, its Done, and the launch
/// origin that decides window or mark.
@MainActor
@Suite("What's new surfaces (#1542)", .serialized)
struct WhatsNewSurfaceTests {
    @Test("the quick menu offers What's New only while it waits")
    func quickMenuRow() async throws {
        LocalizationManager.shared.select("en")
        let (coordinator, _, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        let controller = StatusItemController(item: RowFakeStatusItem())
        controller.updater = WhatsNewFakeUpdater(whatsNew: coordinator)
        #expect(controller.makeWhatsNewItem() == nil)
        await coordinator.launched(opensWindow: false, existingUser: true)
        let row = try #require(controller.makeWhatsNewItem())
        #expect(row.title == "What's New in KiwiDesk 9999.2.0…")
        #expect(row.isEnabled)
        #expect(row.target === controller)
    }

    /// The mark on both channels, and a waiting update outranks
    /// it — one badge, the update's words.
    @Test("the status item carries the mark, the update outranking it")
    func statusMark() async throws {
        LocalizationManager.shared.select("en")
        let (coordinator, _, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        let item = RowFakeStatusItem()
        let controller = StatusItemController(item: item)
        let updater = WhatsNewFakeUpdater(whatsNew: coordinator)
        controller.updater = updater
        let button = try #require(controller.anchorButton)
        #expect(
            !(button.image is StatusItemController.UpdateMarkImage)
        )
        await coordinator.launched(opensWindow: false, existingUser: true)
        #expect(button.image is StatusItemController.UpdateMarkImage)
        #expect(
            button.accessibilityLabel()
                == "KiwiDesk (what's new in 9999.2.0)"
        )
        updater.updatePending = true
        #expect(button.accessibilityLabel() == "KiwiDesk (update available)")
    }

    /// Done — or the close — answers it: the version is recorded
    /// and nothing waits.
    @Test("Done answers it")
    func doneAnswers() async throws {
        var shown: WhatsNewWindowController?
        let (coordinator, record, _) = try WhatsNewFixture.coordinator(
            current: "9999.2.0",
            lastRun: "9999.1.0",
            feed: WhatsNewFixture.items(["9999.2.0"])
        )
        coordinator.presents = { shown = $0 }
        await coordinator.launched(opensWindow: true, existingUser: true)
        let window = try #require(shown).makeWindow()
        _ = try #require(shown).windowShouldClose(window)
        #expect(record.lastRun == "9999.2.0")
        #expect(coordinator.waiting == nil)
    }

    // MARK: - Launch origin

    /// Read off the open-application event: its login-item mark,
    /// or none; no event at all is unknown, never the user's.
    @Test("the launch origin reads the open event")
    func launchOrigin() {
        func open(_ property: OSType?) -> NSAppleEventDescriptor {
            let event = NSAppleEventDescriptor(
                eventClass: kCoreEventClass,
                eventID: kAEOpenApplication,
                targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            if let property {
                event.setParam(
                    NSAppleEventDescriptor(enumCode: property),
                    forKeyword: keyAEPropData
                )
            }
            return event
        }
        #expect(LaunchOrigin.of(open(nil)) == .user)
        #expect(
            LaunchOrigin.of(open(OSType(keyAELaunchedAsLogInItem)))
                == .login
        )
        #expect(LaunchOrigin.of(nil) == .unknown)
    }
}
