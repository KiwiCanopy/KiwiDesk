import Foundation
import Testing

@testable import KiwiDeskCore

/// Every key the Pocket's grown list answers is one KiwiHub keeps
/// under any modifier (#3398), so `kiwihub.set_key` refuses it and
/// no alternative the list reads can shadow it.
@Suite("The Pocket list's keys are KiwiHub's kept keys")
struct PocketListKeyParityTests {
    @Test("panelKeeps holds every list key under every modifier")
    func listKeysAreKept() {
        let codes = BarPeekPanel.ListKey.all
        #expect(!codes.isEmpty)
        let each: [HotkeyModifiers] = [.control, .option, .shift, .command]
        for mask in 0..<(1 << each.count) {
            var held: HotkeyModifiers = []
            for (bit, modifier) in each.enumerated()
            where mask & (1 << bit) != 0 {
                held.insert(modifier)
            }
            for code in codes {
                let combo = KeyCombo(keyCode: UInt32(code), modifiers: held)
                #expect(
                    KiwiHubKeyRefusal.panelKeeps(combo),
                    "key \(code) under \(held.rawValue)"
                )
            }
        }
    }
}
