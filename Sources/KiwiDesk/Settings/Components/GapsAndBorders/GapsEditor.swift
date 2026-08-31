import KiwiDeskCore
import SwiftUI

/// Uniform and per-edge gap configuration editor
/// (`GapsBordersGates`, #68 §3.14).
struct GapsEditor: View {
    @ObservedObject var model: SettingsModel
    @State private var outerExpanded = false
    @State private var innerExpanded = false

    /// Drawers catalog declarations for gap edge controls.
    private var perEdge: SettingsDrawer<GapEdgeControls> {
        SettingsCatalog.gapsAndBorders.gapsPerEdge
    }

    private var perAxis: SettingsDrawer<GapAxisControls> {
        SettingsCatalog.gapsAndBorders.gapsPerAxis
    }

    private var gates: GapsBordersGates {
        GapsBordersGates(settings: model.config.settings)
    }

    var body: some View {
        SettingsSection(SettingsCatalog.gapsAndBorders.gapsCard) {
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

    private func masterReadout(
        _ unified: Binding<CGFloat>,
        _ mixed: Bool
    ) -> String {
        mixed
            ? L("gaps.mixed", "mixed")
            : "\(Int(unified.wrappedValue)) pt"
    }

    private func masterRow(
        label: String,
        unified: Binding<CGFloat>,
        mixed: Bool
    ) -> some View {
        SettingsRowShape {
            SettingsRowLabel(label: label)
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { Double(unified.wrappedValue) },
                        set: {
                            unified.wrappedValue = CGFloat($0)
                        }
                    ),
                    range: 0...100,
                    step: 1,
                    label: label,
                    spokenValue: masterReadout(unified, mixed)
                )
                .disabled(mixed)
                Text(masterReadout(unified, mixed))
                    .settingsReadout()
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.body.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .help(
                        mixed
                            ? GapsBordersGateHelp.sentence(
                                for: .gapsDiffer
                            )
                            : ""
                    )
            }
        }
    }

    private var outer: Gaps.Outer {
        model.config.settings.gapsGlobal.outer
    }

    private var inner: Gaps.Inner {
        model.config.settings.gapsGlobal.inner
    }

    // The master slider is inert while its edges/axes differ.
    // The predicate is the census's, resolved once in
    // `GapsBordersGates`, so the view never re-derives "differ"
    // beside the gate that declares it (#678, gui.md).
    private var outerMixed: Bool {
        gates.inertReason(for: .gaps(.outer)) != nil
    }

    private var innerMixed: Bool {
        gates.inertReason(for: .gaps(.inner)) != nil
    }

    /// Master slider binding updating all outer edges simultaneously.
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

    /// Automatically expands disclosure when edge values differ.
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

/// Slider row for individual gap dimensions (`SettingsDisclosure`, #277).
private struct GapRow: View {
    let control: SettingsControl
    @Binding var value: CGFloat

    var body: some View {
        row.searchAnchored(control)
    }

    private var row: some View {
        SettingsRowShape {
            SettingsRowLabel(label: control.text)
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = CGFloat($0) }
                    ),
                    range: 0...100,
                    step: 1,
                    label: control.text,
                    spokenValue: "\(Int(value)) pt"
                )
                Text("\(Int(value)) pt")
                    .settingsReadout()
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.body.monospacedDigit())
            }
        }
    }
}
