import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Hyper key card's take-over offer (#2471): drawn from Core's
/// `claimable` verdict alone, and its alert names the remap.
@Suite("Hyper take-over offer")
@MainActor
struct HyperTakeOverOfferTests {
    private static let claimable = HyperForeignRemap(
        source: .capsLock,
        destination: .f18,
        claimable: true
    )

    @Test("the offer follows Core's claimable verdict")
    func offerFollowsVerdict() {
        let offer = HyperKeyRow.takeOverOffer
        #expect(
            offer(.refused(Self.claimable), false) == Self.claimable
        )
        let named = HyperForeignRemap(source: .capsLock, destination: .f18)
        #expect(offer(.refused(named), false) == nil)
        #expect(offer(.refused(nil), false) == nil)
        #expect(offer(.refused(Self.claimable), true) == nil)
        #expect(offer(.on, false) == nil)
    }

    @Test("the row draws the offer from the live status")
    func wiring() throws {
        let row = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/HyperKeyRow.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(row.contains("Self.takeOverOffer("))
        #expect(row.contains("HyperTakeOverButton(model: model"))
        // Core decides what is claimable: the row reads the
        // foreign remap's keys nowhere, so it cannot compare them.
        #expect(!row.contains(".source"))
        #expect(!row.contains(".destination"))
    }

    @Test("the alert names the remap it takes over")
    func messageNamesTheRemap() {
        LocalizationManager.shared.select("en")
        let text = HyperTakeOverButton.message(Self.claimable)
        #expect(text.contains("the remap of Caps Lock to F18"))
        #expect(text.contains("listens for F18"))
        let caption = HyperKeyWords.trouble(.refused(Self.claimable))
        #expect(caption?.contains("KiwiDesk would set itself") == true)
    }
}
