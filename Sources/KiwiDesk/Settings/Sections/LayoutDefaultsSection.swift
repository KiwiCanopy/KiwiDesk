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
            }
            .padding(16)
        }
    }

    private var minSizeSection: some View {
        SettingsSection("Minimum window size") {
            HStack {
                Slider(
                    value: $model.config.settings
                        .minWindowSize,
                    in: 100...800,
                    step: 10
                )
                Text(
                    "\(Int(model.config.settings.minWindowSize))"
                        + " pt"
                )
                .frame(width: 56, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
            }
        }
    }
}
