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

    /// `kVK_ANSI_Keypad0`-`9`, in digit order — the independent
    /// source both twin-table pins read. Indexed by the digit,
    /// so `carbonKeypadDigits[4]` is keypad `4`.
    private let carbonKeypadDigits: [UInt32] = [
        UInt32(kVK_ANSI_Keypad0), UInt32(kVK_ANSI_Keypad1),
        UInt32(kVK_ANSI_Keypad2), UInt32(kVK_ANSI_Keypad3),
        UInt32(kVK_ANSI_Keypad4), UInt32(kVK_ANSI_Keypad5),
        UInt32(kVK_ANSI_Keypad6), UInt32(kVK_ANSI_Keypad7),
        UInt32(kVK_ANSI_Keypad8), UInt32(kVK_ANSI_Keypad9),
    ]

    @Test("Every twin's keypad side is the Carbon keypad code")
    func keypadSidePinnedToCarbon() {
        #expect(
            Set(KeypadKeys.digitTwins.keys)
                == Set(carbonKeypadDigits)
        )
    }

    /// Pins the pad-to-row PAIRING against an independent source
    /// — each digit's own Carbon constant — rather than against
    /// the table itself.
    ///
    /// The obvious spelling, `rowTwin(of: keypadTwin(of: row))
    /// == row`, is true by construction of the dictionary for
    /// ANY table, transposed or not, so it cannot catch the swap
    /// it claims to. This one does.
    @Test("Every twin's row side is that digit's own code")
    func rowSidePinnedToKeyCodes() throws {
        for digit in 0...9 {
            let name = String(digit)
            let row = try #require(KeyCombo.keyCodes[name])
            let pad = carbonKeypadDigits[digit]
            #expect(
                KeypadKeys.keypadTwin(of: row) == pad,
                "digit \(name) pairs with the wrong keypad key"
            )
            #expect(
                KeypadKeys.rowTwin(of: pad) == row,
                "keypad \(name) points at the wrong row key"
            )
        }
    }

    /// The digit half is pinned against Carbon above; this is the
    /// other half of the vocabulary. Every one of these was
    /// correct the day it was typed and would bind the wrong
    /// physical key in silence if edited.
    @Test("Every non-digit keypad key is its Carbon code")
    func nonDigitCodesPinnedToCarbon() {
        let expected: [String: UInt32] = [
            "keypadplus": UInt32(kVK_ANSI_KeypadPlus),
            "keypadminus": UInt32(kVK_ANSI_KeypadMinus),
            "keypadmultiply": UInt32(kVK_ANSI_KeypadMultiply),
            "keypaddivide": UInt32(kVK_ANSI_KeypadDivide),
            "keypaddecimal": UInt32(kVK_ANSI_KeypadDecimal),
            "keypadequals": UInt32(kVK_ANSI_KeypadEquals),
            "keypadenter": UInt32(kVK_ANSI_KeypadEnter),
            "keypadclear": UInt32(kVK_ANSI_KeypadClear),
        ]
        for (name, code) in expected {
            #expect(
                KeyCombo.keyCodes[name] == code,
                "\(name) is not its Carbon key code"
            )
        }
    }

    /// `KeyCombo.keyCodes` merges the main block with
    /// `KeypadKeys.names`, and the tie-break keeps the MAIN
    /// entry — so a name collision would silently un-home a key
    /// this enum is supposed to own, which is the opposite of
    /// "KeypadKeys is the one home". Nothing else would notice.
    @Test("No keypad name is shadowed by a main-block name")
    func keypadNamesAreNotShadowed() {
        for (name, code) in KeypadKeys.names {
            #expect(
                KeyCombo.keyCodes[name] == code,
                "\(name) resolved to a main-block code"
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
    /// so its refusal is reported — and the twin is then never
    /// registered at all, or the keypad would keep firing a
    /// binding the Settings caption calls ungranted.
    @Test("A refused AUTHORED code registers no twin either")
    func refusedAuthoredCodeIsAFailure() throws {
        let registrar = RecordingRegistrar()
        let row = try #require(KeyCombo.keyCodes["4"])
        registrar.deniedKeyCodes = [row]
        let manager = KeybindingManager(registrar: registrar)
        let combo = try #require(KeyCombo.parse("control+4"))
        manager.bind(combo, ref: 1)

        #expect(manager.activationFailures == [combo])
        #expect(registrar.liveCodes.isEmpty)
    }

    // MARK: - The invariant downstream readers lean on

    /// `names` resolves the digit aliases to ROW codes, so a
    /// parsed `KeyCombo` can never carry a keypad digit code.
    /// That is precisely why conflict detection, the importer,
    /// `SystemShortcuts` and the Settings board all stayed
    /// correct without an edit — they compare and draw row
    /// codes, and only ever see row codes. Making `keypad4`
    /// bindable apart from `4` would break this silently, and
    /// split conflict detection from registration.
    @Test("No parseable key name resolves to a keypad digit")
    func noNameResolvesToAKeypadDigitCode() {
        #expect(
            Set(KeyCombo.keyCodes.values)
                .isDisjoint(with: KeypadKeys.digitTwins.keys)
        )
    }

    /// Keypad Clear and Enter print no character on any layout,
    /// so each needs a fixed glyph — without one the chord
    /// renders as the uppercased key NAME ("KEYPADCLEAR") in the
    /// recorder, the Shortcuts list and the menu. The rest of
    /// the keypad (`+ − × ÷ . =`) prints, and resolves through
    /// the active layout instead.
    @Test("The non-printing keypad keys carry fixed glyphs")
    func nonPrintingKeypadKeysHaveGlyphs() throws {
        let clear = try #require(KeyCombo.parse("keypadclear"))
        let enter = try #require(KeyCombo.parse("keypadenter"))
        #expect(
            ComboSymbols.specialKeyGlyph(clear.keyCode) != nil
        )
        #expect(
            ComboSymbols.specialKeyGlyph(enter.keyCode) != nil
        )
    }
}
