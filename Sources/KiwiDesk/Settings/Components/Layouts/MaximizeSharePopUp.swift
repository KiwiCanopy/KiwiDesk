import KiwiDeskCore
import SwiftUI

/// A Maximize share's pop-up (#3062): the five fractions, a stored
/// value outside them as a checked item above a separator, then
/// "Custom…", which opens an anchored percent popover. Layout
/// Defaults' shape rows and a Space's own rows (#3090) both draw it.
struct MaximizeSharePopUp: View {
    @Binding var value: Double
    /// The pop-up's spoken name.
    let label: String
    /// The Custom popover's column name.
    let column: String
    /// The open Custom popover (#3062).
    @State private var custom: MaximizeCustomRequest?

    var body: some View {
        let offMenu = Self.offMenuShare(value)
        let selection = Binding<Double>(
            get: { Self.selection(value) },
            set: { picked in
                if picked == MaximizeCustomShare.tag {
                    custom = MaximizeCustomRequest(
                        seed: MaximizeCustomShare.percent(of: value)
                    )
                } else {
                    value = picked
                }
            }
        )
        let spoken = SettingsValueReadout.percent(value)
        return Picker(label, selection: selection) {
            if let offMenu {
                Text(spoken).tag(offMenu)
                Divider()
            }
            ForEach(FractionChips.shares, id: \.glyph) { share in
                Text(share.glyph).tag(share.value)
            }
            Divider()
            Text(L("layout_defaults.maximize.custom", "Custom…"))
                .tag(MaximizeCustomShare.tag)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        // A menu pop-up draws at its own width whatever frame it
        // gets; natural width on the cell's leading edge aligns it.
        .fixedSize()
        .accessibilityLabel(label)
        .accessibilityValue(spoken)
        .popover(item: customBinding) { request in
            MaximizeCustomPopover(
                percent: Binding(
                    get: { custom?.percent ?? request.percent },
                    set: { custom?.percent = $0 }
                ),
                column: column,
                cancel: { custom?.cancelled = true }
            )
            .settingsPopoverChrome()
        }
    }

    /// The Custom popover's request. Its dismissal — Return, a click
    /// outside — writes the typed share, unless Escape cancelled or
    /// nothing was typed, which keeps an exact stored share; a
    /// teardown dismisses nothing, so a closing window writes no
    /// draft.
    private var customBinding: Binding<MaximizeCustomRequest?> {
        Binding(
            get: { custom },
            set: { new in
                if new == nil, let open = custom, !open.cancelled,
                    open.percent != open.seed
                {
                    value = MaximizeCustomShare.share(
                        forPercent: open.percent
                    )
                }
                custom = new
            }
        )
    }

    /// A stored share none of the five fractions reads as — one
    /// Lua or the CLI set — which the pop-up keeps as an extra
    /// checked item; nil for a preset. Custom… writes one too.
    static func offMenuShare(_ stored: Double) -> Double? {
        FractionChips.shares.contains {
            FractionChips.matches(stored, $0.value)
        } ? nil : stored
    }

    /// The tag a stored share checks: its preset's own value, so a
    /// share typed as 0.6667 checks ⅔, or itself when off the menu.
    static func selection(_ stored: Double) -> Double {
        FractionChips.shares.first {
            FractionChips.matches(stored, $0.value)
        }?.value ?? stored
    }

    /// `stored` as the pop-up shows it: its fraction's glyph, else
    /// its percent — the readout a Space's unset row follows.
    static func glyph(_ stored: Double) -> String {
        FractionChips.shares.first {
            FractionChips.matches(stored, $0.value)
        }?.glyph ?? SettingsValueReadout.percent(stored)
    }
}
