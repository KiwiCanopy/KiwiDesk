import KiwiDeskCore
import SwiftUI

/// Global-gaps editor: outer per-edge gaps and inner
/// horizontal/vertical gaps, bound directly to
/// `model.config.settings.gapsGlobal`.
struct GapsEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection("Global Gaps") {
            outerGaps
            Divider()
            innerGaps
        }
    }

    // MARK: - Outer

    private var outerGaps: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Outer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            GapRow(
                label: "Top",
                value: $model.config.settings
                    .gapsGlobal.outer.top
            )
            GapRow(
                label: "Bottom",
                value: $model.config.settings
                    .gapsGlobal.outer.bottom
            )
            GapRow(
                label: "Left",
                value: $model.config.settings
                    .gapsGlobal.outer.left
            )
            GapRow(
                label: "Right",
                value: $model.config.settings
                    .gapsGlobal.outer.right
            )
        }
    }

    // MARK: - Inner

    private var innerGaps: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inner")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            GapRow(
                label: "Horizontal",
                value: $model.config.settings
                    .gapsGlobal.inner.horizontal
            )
            GapRow(
                label: "Vertical",
                value: $model.config.settings
                    .gapsGlobal.inner.vertical
            )
        }
    }
}

// MARK: - GapRow

/// A slider row for a single gap value (0–100 pt).
private struct GapRow: View {
    let label: String
    @Binding var value: CGFloat

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            Slider(value: $value, in: 0...100, step: 1)
            Text("\(Int(value)) pt")
                .frame(width: 52, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}
