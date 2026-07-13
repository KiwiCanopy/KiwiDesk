import KiwiDeskCore
import SwiftUI

/// The per-row layout-mode picker and the live-vs-saved drift
/// caption (#123), split from `SpacesSection` for file size.
extension SpacesSection {
    func modePicker(_ space: SpaceID) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
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

            // The one drift source (`model.layoutDrift`), shared
            // with the footer captions — never a second inline
            // comparison, and no profile read in the render path.
            if space == model.core.activeSpace?.id,
                let drift = model.layoutDrift
            {
                Text(
                    L(
                        "settings.layout.drift",
                        "Live: %1$@ — profile has %2$@ (not saved)",
                        drift.live.displayName,
                        drift.saved.displayName
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Setting a space to the default `bsp` removes its entry
    /// (the writer treats absent as `bsp`).
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
