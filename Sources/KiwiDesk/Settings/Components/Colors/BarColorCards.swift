import KiwiDeskCore
import SwiftUI

/// The two bar groups on Advanced Colours (turn 12b). Each keeps
/// its accent colours at rest and puts the rest behind one "More
/// colors" drawer — the split the interim colour cards already
/// made, now read from the census's tiers.
///
/// "More colors", never "Advanced colors": inside an area whose
/// own name is Advanced Colors, that adjective re-scopes onto the
/// area and reads as mode depth — a row tier and a mode depth
/// must never be spelled with one word. The drawer's collapsed
/// summary does the naming instead. Argued in
/// `docs/ui-patterns.md` ("Advanced" prefixes a disclosure's
/// noun only when…).
struct SpaceBarColorCard: View {
    @ObservedObject var model: SettingsModel
    @State private var moreExpanded = false

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }
    private var allows: Bool {
        gates.bars.containerReason(for: .spaceBar) == nil
    }

    var body: some View {
        // The header `?` is the block gate's live anchor (#527),
        // and from here it must also say WHERE: the Show switch
        // is on another page now.
        SettingsSection(
            SettingsCatalog.advancedColors.spaceBarGroup,
            help: allows ? nil : AdvancedColorsHelp.spaceBarOff
        ) {
            SpaceBarPreviewStrip(
                style: model.config.settings.spaceBarStyle,
                appBar: model.config.settings.appBarStyle,
                sameEdge: model.config.settings
                    .spaceBarSharesEdgeWithAppBar
            )
            ColorGrid {
                AdvancedColorRows(
                    model: model,
                    keys: ColorsRowOrder.spaceBarAtRest,
                    allows: allows,
                    gateHelp: AdvancedColorsHelp.spaceBarOff
                )
            }
            SettingsDisclosure(
                SettingsCatalog.advancedColors.spaceBarMore,
                chrome: .inline(font: .subheadline),
                isExpanded: $moreExpanded,
                scrollHoisted: true
            ) {
                ColorGrid {
                    AdvancedColorRows(
                        model: model,
                        keys: ColorsRowOrder.spaceBarMore,
                        allows: allows,
                        gateHelp: AdvancedColorsHelp.spaceBarOff
                    )
                }
                .padding(.top, 8)
            } accessory: {
                if !moreExpanded {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var summary: String {
        L(
            "colors.more.space_bar.summary",
            "Plate, highlight, hover, badges"
        )
    }
}

struct AppBarColorCard: View {
    @ObservedObject var model: SettingsModel
    @State private var moreExpanded = false

    private var gates: AdvancedColorsGates {
        AdvancedColorsGates(settings: model.config.settings)
    }
    private var allows: Bool {
        gates.bars.containerReason(for: .appBar) == nil
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.advancedColors.appBarGroup,
            help: allows ? nil : AdvancedColorsHelp.appBarOff
        ) {
            AppBarPreviewStrip(
                style: model.config.settings.appBarStyle
            )
            ColorGrid {
                AdvancedColorRows(
                    model: model,
                    keys: ColorsRowOrder.appBarAtRest,
                    allows: allows,
                    gateHelp: AdvancedColorsHelp.appBarOff
                )
            }
            SettingsDisclosure(
                SettingsCatalog.advancedColors.appBarMore,
                chrome: .inline(font: .subheadline),
                isExpanded: $moreExpanded,
                scrollHoisted: true
            ) {
                ColorGrid {
                    AdvancedColorRows(
                        model: model,
                        keys: ColorsRowOrder.appBarMore,
                        allows: allows,
                        gateHelp: AdvancedColorsHelp.appBarOff
                    )
                }
                .padding(.top, 8)
            } accessory: {
                if !moreExpanded {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var summary: String {
        L(
            "colors.more.app_bar.summary",
            "Item, active item, hover, badges"
        )
    }
}

/// One group's rows, each carrying its container gate in
/// PARALLEL with its own row gate — never nested, and honoring
/// `exemptFromContainerGate` as data the way the Bars cards do.
struct AdvancedColorRows: View {
    @ObservedObject var model: SettingsModel
    let keys: [SettingKey]
    var allows = true
    var gateHelp = ""

    var body: some View {
        ForEach(keys, id: \.id) { key in
            let gate = Self.gate(allows: allows, key: key)
            AdvancedColorRow(
                model: model,
                key: key,
                ownPredicateLive: gate.rowPredicateLive
            )
            .modifier(
                GreyOut(active: gate.containerGrey, help: gateHelp)
            )
        }
    }

    /// How a row's two gates resolve — ONE decision with one
    /// answer.
    ///
    /// It is hoisted because the two halves were computed six
    /// lines apart in `body` and disagreed about the exemption:
    /// the container grey honored it, the row predicate did not.
    /// An exempt row under a closed container therefore had its
    /// block grey lifted AND its own predicate suppressed —
    /// an editable swatch tinting nothing, explaining nothing,
    /// the exact opposite of what the exemption asks for. The
    /// exemption means "escape the CONTAINER gate", not "escape
    /// both".
    ///
    /// That disagreement is the warrant, not testability: a
    /// two-line expression does not leave a view because a test
    /// wants a handle on it. Being assertable is what the
    /// co-location bought, and it matters here because nothing
    /// in this area is exempt yet — so no rendered behaviour
    /// distinguishes the two forms, and only a direct assertion
    /// can hold the rule until the first exemption lands.
    ///
    /// The two values are exact complements today. Both are
    /// named anyway: a future exemption could want the block
    /// grey lifted WITHOUT re-arming the row's own predicate,
    /// and only this shape can say so.
    static func gate(
        allows: Bool,
        key: SettingKey
    ) -> (rowPredicateLive: Bool, containerGrey: Bool) {
        let exempt = key.placement.exemptFromContainerGate
        return (
            rowPredicateLive: allows || exempt,
            containerGrey: !allows && !exempt
        )
    }
}
