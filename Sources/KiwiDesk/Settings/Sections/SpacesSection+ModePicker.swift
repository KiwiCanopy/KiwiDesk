import KiwiDeskCore
import SwiftUI

/// Space layout mode picker and live drift indicator (`SpacesSection`, #123).
extension SpacesSection {
    func modePicker(_ space: SpaceID) -> some View {
        let modeHint = L(
            "spaces.mode.help",
            "Layout mode for this Space"
        )
        return VStack(alignment: .trailing, spacing: 4) {
            Picker("", selection: modeBinding(space)) {
                ForEach(LayoutMode.allCases, id: \.self) { mode in
                    Label(
                        mode.displayName,
                        systemImage: mode.glyph
                    )
                    .tag(mode)
                }
            }
            .labelsHidden()
            .controlSize(.large)
            .frame(width: 150)
            .help(modeHint)
            .accessibilityLabel(modeHint)
            .accessibilityValue(
                modeBinding(space).wrappedValue.displayName
            )
            // Focused row target for navigation returns (#678 Phase 4, #812).
            .focused($returningRow, equals: space)
        }
    }

    /// Binding for space layout mode omitting default bsp value.
    func modeBinding(
        _ space: SpaceID
    ) -> Binding<LayoutMode> {
        Binding(
            get: { model.config.spaceModes[space] ?? .bsp },
            set: { mode in
                model.config.spaceModes[space] =
                    mode == .bsp ? nil : mode
            }
        )
    }
}
