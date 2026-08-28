import Carbon.HIToolbox
import Foundation
import Testing

@testable import KiwiDeskCore

/// A registrar that records what is LIVE — id → key code, with
/// `unregister` removing it — so a test can assert how many
/// physical keys one binding actually claims, rather than how
/// many registration calls were made across re-activations.
@MainActor
private final class RecordingRegistrar: HotkeyRegistrar {
    var deniedKeyCodes: Set<UInt32> = []
    private var nextID: UInt32 = 1
    private(set) var live: [UInt32: UInt32] = [:]

    var liveCodes: Set<UInt32> { Set(live.values) }

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        guard !deniedKeyCodes.contains(keyCode) else {
            return nil
        }
        let id = nextID
        nextID += 1
        live[id] = keyCode
        return id
    }

    func unregister(id: UInt32) {
        live[id] = nil
    }
}

/// The keypad is bindable, and its ten digits are the same key
/// as their number-row twin (#1074).
@Suite("Keypad keys (#1074)", .serialized)
@MainActor
struct KeypadKeysTests {

    // MARK: - The twin table itself

    @Test("Every twin's keypad side is the Carbon keypad code")
    func keypadSidePinnedToCarbon() {
        let carbon: [UInt32] = [
            UInt32(kVK_ANSI_Keypad0), UInt32(kVK_ANSI_Keypad1),
            UInt32(kVK_ANSI_Keypad2), UInt32(kVK_ANSI_Keypad3),
            UInt32(kVK_ANSI_Keypad4), UInt32(kVK_ANSI_Keypad5),
            UInt32(kVK_ANSI_Keypad6), UInt32(kVK_ANSI_Keypad7),
            UInt32(kVK_ANSI_Keypad8), UInt32(kVK_ANSI_Keypad9),
        ]
        #expect(
            Set(KeypadKeys.digitTwins.keys) == Set(carbon)
        )
    }

    /// The other side of the same table: a transposed pair here
    /// would bind the wrong digit silently, which is precisely
    /// what a hand-read of the literals cannot catch.
    @Test("Every twin's row side is that digit's own code")
    func rowSidePinnedToKeyCodes() throws {
        for digit in 0...9 {
            let name = String(digit)
            let row = try #require(KeyCombo.keyCodes[name])
            let pad = try #require(
                KeypadKeys.keypadTwin(of: row),
                "digit \(name) has no keypad twin"
            )
            #expect(
                KeypadKeys.rowTwin(of: pad) == row,
                "digit \(name) does not round-trip"
            )
        }
    }

    @Test("A key with no keypad twin reports none")
    func lettersHaveNoTwin() throws {
        let letter = try #require(KeyCombo.keyCodes["a"])
        #expect(KeypadKeys.keypadTwin(of: letter) == nil)
        #expect(KeypadKeys.rowTwin(of: letter) == nil)
    }

    // MARK: - Naming and round-tripping

    @Test("A keypad digit names itself as its digit")
    func keypadDigitNamesAsTheDigit() {
        let pad = UInt32(kVK_ANSI_Keypad4)
        #expect(KeyCombo.keyName(for: pad) == "4")
    }

    /// The recorder captures a raw key code, so a keypad press
    /// has to canonicalise to the code its binding is stored
    /// under or the captured row would never fire.
    @Test("A captured keypad press round-trips to the row code")
    func capturedKeypadPressRoundTrips() throws {
        let text = try #require(
            KeyCombo.comboString(
                keyCode: UInt32(kVK_ANSI_Keypad4),
                command: false,
                option: true,
                control: true,
                shift: false
            )
        )
        #expect(text == "control+option+4")
        let combo = try #require(KeyCombo.parse(text))
        #expect(combo.keyCode == KeyCombo.keyCodes["4"])
    }

    /// `names` gives every digit a second spelling, so without
    /// the pinned display override the name→code map's iteration
    /// order could render a captured `4` as `keypad4`.
    @Test("The alias never shadows a digit's display name")
    func digitNameIsNotShadowedByAlias() throws {
        for digit in 0...9 {
            let name = String(digit)
            let row = try #require(KeyCombo.keyCodes[name])
            #expect(
                KeyCombo.keyName(for: row) == name,
                "digit \(name) rendered as its alias"
            )
        }
    }

    @Test("keypadN parses to the number-row code")
    func keypadAliasParsesToRowCode() throws {
        let alias = try #require(KeyCombo.parse("keypad4"))
        #expect(alias.keyCode == KeyCombo.keyCodes["4"])
        #expect(KeyCombo.equivalent("control+keypad4", "control+4"))
    }

    @Test("A non-digit keypad key is its own bindable key")
    func nonDigitKeypadKeysStandAlone() throws {
        let enter = try #require(KeyCombo.parse("keypadenter"))
        #expect(enter.keyCode == UInt32(kVK_ANSI_KeypadEnter))
        #expect(KeypadKeys.rowTwin(of: enter.keyCode) == nil)
        let plus = try #require(KeyCombo.parse("keypadplus"))
        #expect(plus.keyCode == UInt32(kVK_ANSI_KeypadPlus))
    }

    // MARK: - Registration

    @Test("A digit binding claims both physical keys")
    func digitBindingRegistersBothKeys() throws {
        let registrar = RecordingRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        let combo = try #require(KeyCombo.parse("control+4"))
        manager.bind(combo, ref: 1)

        let row = try #require(KeyCombo.keyCodes["4"])
        let pad = try #require(KeypadKeys.keypadTwin(of: row))
        #expect(registrar.liveCodes == [row, pad])
        // Both registrations answer to the SAME binding, or the
        // keypad press would fire nothing.
        #expect(manager.activeBindings.count == 2)
        #expect(
            Set(manager.activeBindings.values.map(\.ref)) == [1]
        )
    }

    @Test("A key with no twin claims exactly one physical key")
    func nonDigitBindingRegistersOneKey() throws {
        let registrar = RecordingRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        let combo = try #require(KeyCombo.parse("control+j"))
        manager.bind(combo, ref: 1)

        #expect(registrar.liveCodes.count == 1)
        #expect(manager.activeBindings.count == 1)
    }

    /// The shortcut still works from the number row, so cueing a
    /// conflict would name a failure the user can neither see
    /// nor fix.
    @Test("A refused TWIN is not an activation failure")
    func refusedTwinIsNotAFailure() throws {
        let registrar = RecordingRegistrar()
        let row = try #require(KeyCombo.keyCodes["4"])
        let pad = try #require(KeypadKeys.keypadTwin(of: row))
        registrar.deniedKeyCodes = [pad]
        let manager = KeybindingManager(registrar: registrar)
        let combo = try #require(KeyCombo.parse("control+4"))
        manager.bind(combo, ref: 1)

        #expect(manager.activationFailures.isEmpty)
        #expect(registrar.liveCodes == [row])
    }

    /// The authored key is the one the user wrote and can see,
    /// so its refusal is still reported even when the keypad
    /// twin happened to land.
    @Test("A refused AUTHORED code is still a failure")
    func refusedAuthoredCodeIsAFailure() throws {
        let registrar = RecordingRegistrar()
        let row = try #require(KeyCombo.keyCodes["4"])
        registrar.deniedKeyCodes = [row]
        let manager = KeybindingManager(registrar: registrar)
        let combo = try #require(KeyCombo.parse("control+4"))
        manager.bind(combo, ref: 1)

        #expect(manager.activationFailures == [combo])
    }
}
