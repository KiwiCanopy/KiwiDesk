import KiwiDeskCore
import SwiftUI

/// Gaps, uniform-first (#68 §3.14): one Outer and one Inner
/// slider for the everyday "more/less breathing room" action,
/// each with a per-edge/per-axis disclosure holding the six
/// individual sliders. When stored values differ per edge the
/// group renders pre-expanded and the master slider disables
/// itself, so a carefully tuned asymmetric setup can't be
/// blindly overwritten. All six values stay individually
/// settable.
struct GapsEditor: View {
    @ObservedObject var model: SettingsModel
    @State private var outerExpanded = false
    @State private var innerExpanded = false

    var body: some View {
        SettingsSection("Gaps") {
            GapsDiagram(outer: outer, inner: inner)
            masterRow(
                label: "Outer gap",
                unified: outerUnified,
                mixed: outerMixed
            )
            DisclosureGroup(
                "Per-edge…",
                isExpanded: outerDisclosure
            ) {
                VStack(alignment: .leading, spacing: 6) {
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
                .padding(.top, 4)
            }
            Divider()
            masterRow(
                label: "Inner gap",
                unified: innerUnified,
                mixed: innerMixed
            )
            DisclosureGroup(
                "Per-axis…",
                isExpanded: innerDisclosure
            ) {
                VStack(alignment: .leading, spacing: 6) {
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
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Master rows

    private func masterRow(
        label: String,
        unified: Binding<CGFloat>,
        mixed: Bool
    ) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            GlassSlider(
                value: Binding(
                    get: { Double(unified.wrappedValue) },
                    set: { unified.wrappedValue = CGFloat($0) }
                ),
                range: 0...100,
                step: 1
            )
            .disabled(mixed)
            Text(
                mixed
                    ? "mixed"
                    : "\(Int(unified.wrappedValue)) pt"
            )
            .frame(width: 52, alignment: .trailing)
            .foregroundStyle(.secondary)
            .font(.system(.body, design: .monospaced))
            .help(
                mixed
                    ? "Edges differ — edit them individually "
                        + "below."
                    : ""
            )
        }
    }

    // MARK: - Mixed-state plumbing

    private var outer: Gaps.Outer {
        model.config.settings.gapsGlobal.outer
    }

    private var inner: Gaps.Inner {
        model.config.settings.gapsGlobal.inner
    }

    private var outerMixed: Bool {
        !(outer.top == outer.bottom
            && outer.top == outer.left
            && outer.top == outer.right)
    }

    private var innerMixed: Bool {
        inner.horizontal != inner.vertical
    }

    /// The master slider: reads the shared value, writes every
    /// edge — only enabled while the edges agree.
    private var outerUnified: Binding<CGFloat> {
        Binding(
            get: { outer.top },
            set: { value in
                model.config.settings.gapsGlobal.outer =
                    Gaps.Outer(
                        top: value,
                        bottom: value,
                        left: value,
                        right: value
                    )
            }
        )
    }

    private var innerUnified: Binding<CGFloat> {
        Binding(
            get: { inner.horizontal },
            set: { value in
                model.config.settings.gapsGlobal.inner =
                    Gaps.Inner(
                        horizontal: value,
                        vertical: value
                    )
            }
        )
    }

    /// Pre-expanded while the values are mixed (there is no
    /// master value to show), collapsible again once unified.
    private var outerDisclosure: Binding<Bool> {
        Binding(
            get: { outerExpanded || outerMixed },
            set: { outerExpanded = $0 }
        )
    }

    private var innerDisclosure: Binding<Bool> {
        Binding(
            get: { innerExpanded || innerMixed },
            set: { innerExpanded = $0 }
        )
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
            GlassSlider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = CGFloat($0) }
                ),
                range: 0...100,
                step: 1
            )
            Text("\(Int(value)) pt")
                .frame(width: 52, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}
