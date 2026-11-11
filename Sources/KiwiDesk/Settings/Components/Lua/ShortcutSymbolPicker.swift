import KiwiDeskCore
import SwiftUI

/// The symbol a binding wears in KiwiHub (#2544, #3162): the icon
/// picker over SF Symbols alone, an empty symbol drawn as the
/// binding's default mark. Shared by the Lua bindings' rows and the
/// Key sequences card's popovers.
struct ShortcutSymbolPicker: View {
    @Binding var symbol: String
    /// The binding's name for VoiceOver.
    let name: String
    /// What an empty symbol draws as.
    let placeholder: String
    /// What VoiceOver says for an empty symbol.
    let spokenDefault: String

    var body: some View {
        IconPicker(
            icon: $symbol,
            preview: .chip,
            symbolsOnly: true,
            placeholder: placeholder
        )
        .accessibilityLabel(
            L("shortcuts.lua.symbol_ax", "Symbol for %1$@", name)
        )
        .accessibilityValue(symbol.isEmpty ? spokenDefault : symbol)
    }
}

extension ShortcutSymbolPicker {
    /// A Lua binding's picker, `</>` shown and never named
    /// (config-vocabulary.md).
    static func lua(_ symbol: Binding<String>, name: String) -> Self {
        Self(
            symbol: symbol,
            name: name,
            placeholder: LuaMark.symbol,
            spokenDefault: L("shortcuts.lua.default_symbol", "</>")
        )
    }

    /// A key that opens more keys, `folder` by default (#3162).
    static func branch(_ symbol: Binding<String>, name: String) -> Self {
        Self(
            symbol: symbol,
            name: name,
            placeholder: BranchMark.symbol,
            spokenDefault: L("shortcuts.sequence.default_symbol", "Folder")
        )
    }
}
