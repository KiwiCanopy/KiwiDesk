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

    /// The drawers' catalog declarations — the same values the
    /// index enumerates, so a reveal targeting an edge row knows
    /// its drawer by construction.
    private var perEdge: SettingsDrawer<GapEdgeControls> {
        SettingsCatalog.gapsAndBorders.gapsPerEdge
    }

    private var perAxis: SettingsDrawer<GapAxisControls> {
        SettingsCatalog.gapsAndBorders.gapsPerAxis
    }

    private var gates: GapsBordersGates {
        GapsBordersGates(
            settings: model.config.settings,
            linkedWidth: model.borderWidthLinked
        )
    }

    var body: some View {
        SettingsSection(SettingsCatalog.gapsAndBorders.gapsCard) {
            GapsDiagram(outer: outer, inner: inner)
            masterRow(
                label: L("gaps.outer", "Outer gap"),
                unified: outerUnified,
                mixed: outerMixed
            )
            SettingsDisclosure(
                perEdge,
                isExpanded: outerDisclosure,
                scrollHoisted: true
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    GapRow(
                        control: perEdge.children.edgeTop,
                        value: $model.config.settings
                            .gapsGlobal.outer.top
                    )
                    GapRow(
                        control: perEdge.children.edgeBottom,
                        value: $model.config.settings
                            .gapsGlobal.outer.bottom
                    )
                    GapRow(
                        control: perEdge.children.edgeLeft,
                        value: $model.config.settings
                            .gapsGlobal.outer.left
                    )
                    GapRow(
                        control: perEdge.children.edgeRight,
                        value: $model.config.settings
                            .gapsGlobal.outer.right
                    )
                }
                .padding(.top, 4)
            }
            Divider()
            masterRow(
                label: L("gaps.inner", "Inner gap"),
                unified: innerUnified,
                mixed: innerMixed
            )
            SettingsDisclosure(
                perAxis,
                isExpanded: innerDisclosure,
                scrollHoisted: true
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    GapRow(
                        control: perAxis.children.axisHorizontal,
                        value: $model.config.settings
                            .gapsGlobal.inner.horizontal
                    )
                    GapRow(
                        control: perAxis.children.axisVertical,
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
                .frame(
                    width: SettingsMetrics.labelColumn,
                    alignment: .leading
                )
            SettingsSlider(
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
                    ? L("gaps.mixed", "mixed")
                    : "\(Int(unified.wrappedValue)) pt"
            )
            .frame(
                width: SettingsMetrics.readoutColumn,
                alignment: .trailing
            )
            .foregroundStyle(.secondary)
            .font(.body.monospacedDigit())
            // The other word-valued readout (see `PtSlider`):
            // a longer locale shrinks rather than wrapping and
            // growing the row's height.
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .help(
                mixed
                    ? GapsBordersGateHelp.sentence(for: .gapsDiffer)
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

    // The master slider is inert while its edges / axes differ.
    // The predicate is the census's, resolved once in
    // `GapsBordersGates`, so the view never re-derives "differ"
    // beside the gate that declares it (#678, gui.md).
    private var outerMixed: Bool {
        gates.inertReason(for: .gaps(.outer)) != nil
    }

    private var innerMixed: Bool {
        gates.inertReason(for: .gaps(.inner)) != nil
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

/// A slider row for a single gap value (0–100 pt). Takes its
/// catalog descriptor, so the row is a search anchor by existing
/// — the first drawer-interior controls the catalog reaches
/// (#277); a reveal expands the drawer (`SettingsDisclosure`)
/// and lands here. Self-anchoring, so it takes `.searchAnchored`
/// whole: the wash covers the same rect as the scroll target
/// because, unlike a section card, there is no expanded content
/// below the label to tint by accident.
private struct GapRow: View {
    let control: SettingsControl
    @Binding var value: CGFloat

    var body: some View {
        row.searchAnchored(control)
    }

    private var row: some View {
        HStack {
            Text(control.text)
                .frame(
                    width: SettingsMetrics.labelColumn,
                    alignment: .leading
                )
            SettingsSlider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = CGFloat($0) }
                ),
                range: 0...100,
                step: 1
            )
            Text("\(Int(value)) pt")
                .frame(
                    width: SettingsMetrics.readoutColumn,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)
                .font(.body.monospacedDigit())
        }
    }
}
