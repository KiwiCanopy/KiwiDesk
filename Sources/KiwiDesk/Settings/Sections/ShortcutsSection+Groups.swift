import KiwiDeskCore
import SwiftUI

/// The Built-in part's action groups and Personal's Open
/// applications card, one per page part (#3060, #3184).
extension ShortcutsSection {
    @ViewBuilder func actionGroup(
        _ part: ShortcutsPagePart,
        expander: ShortcutsFamilyRows
    ) -> some View {
        switch part {
        case .showHide:
            ShowHideGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .focus:
            FocusGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .moveWindows:
            MoveWindowsGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .macosDesktops:
            MacOSDesktopsGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .layout:
            LayoutGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .sizeFloat:
            SizeFloatGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .pocket:
            PocketGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .openApplications:
            ApplicationsGroup(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        default:
            EmptyView()
        }
    }
}
