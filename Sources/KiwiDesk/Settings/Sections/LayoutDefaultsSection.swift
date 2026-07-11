import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Layout Defaults (#68 §3.2): the global
/// per-mode placement tuning the Spaces rows' per-space
/// overrides deviate from, plus the minimum window size.
/// Splitting this out of Spaces keeps "define your spaces"
/// (short, daily-adjacent) separate from "tune how a mode
/// behaves" (occasional, denser). Gaps live in Appearance —
/// spacing is a visual, not placement logic (§3.14).
struct LayoutDefaultsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                minSizeSection
                LayoutParamsEditor(model: model)
                ScrollGridEditor(model: model)
                MonocleEditor(model: model)
                TrackEditor(model: model)
            }
            .padding(16)
        }
    }

    private var minSizeSection: some View {
        SettingsSection(
            L(
                "layout_defaults.min_window_size",
                "Minimum window size"
            )
        ) {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: {
                            Double(
                                model.config.settings
                                    .minWindowSize
                            )
                        },
                        set: {
                            model.config.settings
                                .minWindowSize = CGFloat($0)
                        }
                    ),
                    range: 100...800,
                    step: 10
                )
                Text(
                    "\(Int(model.config.settings.minWindowSize))"
                        + " pt"
                )
                .frame(
                    width: SettingsMetrics.readoutColumn,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
            }
        }
    }
}
