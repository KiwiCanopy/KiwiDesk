import Foundation
import KiwiDeskCore
import SwiftUI

/// The key panel's two scopes (#2229): Jump to window's list and
/// the layout picker's tiles, one field above both. ⇥ switches,
/// and so does the other scope's own shortcut while the panel is
/// up.
enum JumpScope: CaseIterable, Equatable {
    case windows
    case layouts

    var other: JumpScope { self == .windows ? .layouts : .windows }

    /// The switch's segment and the footer's ⇥ hint.
    @MainActor var title: String {
        switch self {
        case .windows: return L("jump.scope.windows", "Windows")
        case .layouts: return L("jump.scope.layouts", "Layouts")
        }
    }

    /// The field's placeholder and its VoiceOver name.
    @MainActor var fieldName: String {
        switch self {
        case .windows: return L("jump.field.label", "Jump to window")
        case .layouts:
            return L("layout_defaults.choose", "Choose a layout")
        }
    }
}

extension JumpGhost {
    /// The Layouts scope's field: the selected layout's name — the
    /// typed letters at full ink where they matched, the rest grey
    /// — then what ↩ does with it.
    static func layoutField(name: String, query: String) -> Field {
        var attributed = AttributedString(name)
        attributed.foregroundColor = Color.secondary
        let typed = query.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty,
            let range = attributed.range(
                of: typed,
                options: .caseInsensitive
            )
        {
            attributed[range].foregroundColor = Color.primary
        }
        return Field(
            name: attributed,
            frame: L("layout_picker.field.apply", "%1$@ — Apply")
        )
    }
}
