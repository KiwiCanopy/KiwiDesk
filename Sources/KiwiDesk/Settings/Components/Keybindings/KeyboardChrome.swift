import Carbon.HIToolbox
import KiwiDeskCore
import SwiftUI

/// Modifier scope selection chip for virtual keyboard.
struct ScopeChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    isOn
                        ? SettingsTheme.plateInk
                        : SettingsTheme.ink2
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            isOn
                                ? SettingsTheme.previewPlate
                                : SettingsTheme.sunken
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

/// Reads localized keyboard layout name from active TIS input source.
enum KeyboardInputSource {
    static func localizedName() -> String? {
        guard
            let source = TISCopyCurrentKeyboardLayoutInputSource()?
                .takeRetainedValue()
                ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
                .takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(
                source,
                kTISPropertyLocalizedName
            )
        else { return nil }
        return Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue() as String
    }
}

/// Generates labels and fallbacks for physical keycaps (`ComboSymbols`).
enum KeyboardKeyLabel {
    /// Capped key glyph (`ComboSymbols.capitalisedGlyph`).
    static func capped(_ char: String) -> String {
        ComboSymbols.capitalisedGlyph(char)
    }

    /// Modifier scope chip label string (`KeyboardCensus.ModifierLayer`).
    @MainActor
    static func chipLabel(
        for layer: KeyboardCensus.ModifierLayer
    ) -> String {
        layer.modifiers.isEmpty
            ? L("keyboard.modifier.bare", "No modifier")
            : layer.label
    }

    /// Functional key symbols for macOS keyboard hardware.
    static let functional: [UInt32: String] = [
        36: "↩", 48: "⇥", 49: "space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func fallback(for code: UInt32) -> String {
        if let symbol = functional[code] { return symbol }
        return KeyCombo.keyName(for: code)?.uppercased() ?? ""
    }

    /// Tests whether scalar is printable, excluding private-use
    /// (`UCKeyTranslate`, `NSUpArrowFunctionKey`).
    static func isPrintable(_ char: String) -> Bool {
        guard let scalar = char.unicodeScalars.first,
            char.unicodeScalars.count == 1
        else { return !char.isEmpty }
        if scalar.properties.generalCategory == .privateUse {
            return false
        }
        return !scalar.properties.isDefaultIgnorableCodePoint
            && scalar.value >= 0x20
    }
}

extension KeyboardMatrix.PhysicalType {
    /// Display name for keyboard hardware layout
    /// (`KeyboardMatrix.PhysicalType`).
    var label: String {
        switch self {
        case .ansi: return "ANSI"
        case .iso: return "ISO"
        case .jis: return "JIS"
        }
    }
}
