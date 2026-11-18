import KiwiDeskCore
import SwiftUI

/// A Maximize share's pop-up (#3062, #3460): the five fractions,
/// each with its length on this row's screen, then a stored value
/// outside them as a checked item, then "Custom…", which opens an
/// anchored percent-or-points popover. Layout Defaults' shape rows
/// and a Space's own rows (#3090) both draw it.
struct MaximizeSharePopUp: View {
    @Binding var value: MaximizeLength
    /// The axis this share sizes the other of: a Maximize Height's
    /// share is a width.
    let axis: MaximizeAxis
    /// The visible frame of a screen of this row's shape, which the
    /// menu's lengths and the unit flip read; nil with none.
    let screen: CGRect?
    /// The pop-up's spoken name.
    let label: String
    /// The Custom popover's column name.
    let column: String
    /// The open Custom popover (#3062).
    @State private var custom: MaximizeCustomRequest?

    /// What the menu's items carry.
    enum Tag: Hashable {
        case share(MaximizeLength)
        case custom
    }

    var body: some View {
        let offMenu = Self.offMenuShare(value)
        let selection = Binding<Tag>(
            get: { .share(Self.selection(value)) },
            set: { picked in
                switch picked {
                case .custom:
                    custom = MaximizeCustomRequest(
                        stored: value,
                        axis: axis,
                        screen: screen
                    )
                case .share(let share):
                    value = share
                }
            }
        )
        return Picker(label, selection: selection) {
            ForEach(FractionChips.shares, id: \.glyph) { share in
                Text(presetTitle(share.glyph, share.value))
                    .tag(Tag.share(.fraction(share.value)))
            }
            if let offMenu {
                Divider()
                Text(Self.glyph(offMenu)).tag(Tag.share(offMenu))
            }
            Divider()
            Text(L("layout_defaults.maximize.custom", "Custom…"))
                .tag(Tag.custom)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        // A menu pop-up draws at its own width whatever frame it
        // gets; natural width on the cell's leading edge aligns it.
        .fixedSize()
        .accessibilityLabel(label)
        .accessibilityValue(Self.spoken(value))
        .popover(item: customBinding) { request in
            MaximizeCustomPopover(
                request: Binding(
                    get: { custom ?? request },
                    set: { custom = $0 }
                ),
                column: column
            )
            .settingsPopoverChrome()
        }
    }

    /// A fraction's item: its glyph and, with a screen, the length
    /// it fills there, through the fill's own resolution.
    private func presetTitle(_ glyph: String, _ fraction: Double) -> String {
        guard
            let length = MaximizeCustomShare.points(
                of: .fraction(fraction),
                axis: axis,
                screen: screen
            )
        else { return glyph }
        return "\(glyph)    \(SettingsValueReadout.points(length))"
    }

    /// The popover's request. Its dismissal — Return, a click
    /// outside — writes the typed share, unless Escape cancelled or
    /// nothing was typed, which keeps an exact stored share; a
    /// teardown dismisses nothing, so a closing window writes no
    /// draft.
    private var customBinding: Binding<MaximizeCustomRequest?> {
        Binding(
            get: { custom },
            set: { new in
                if new == nil, let open = custom,
                    let typed = open.committed
                {
                    value = typed
                }
                custom = new
            }
        )
    }

    /// A stored share none of the five fractions reads as — one
    /// Lua or the CLI set, a length — which the pop-up keeps as an
    /// extra checked item; nil for a preset. Custom… writes one too.
    static func offMenuShare(_ stored: MaximizeLength) -> MaximizeLength? {
        guard let fraction = stored.fraction else { return stored }
        return FractionChips.shares.contains {
            FractionChips.matches(fraction, $0.value)
        } ? nil : stored
    }

    /// The tag a stored share checks: its preset's own value, so a
    /// share typed as 0.6667 checks ⅔, or itself when off the menu.
    static func selection(_ stored: MaximizeLength) -> MaximizeLength {
        guard let fraction = stored.fraction else { return stored }
        return FractionChips.shares.first {
            FractionChips.matches(fraction, $0.value)
        }.map { .fraction($0.value) } ?? stored
    }

    /// `stored` as the pop-up shows it: its fraction's glyph, else
    /// its percent or its length — the readout a Space's unset row
    /// follows. A length shows as stored, never as a screen clamps
    /// it (#3460).
    static func glyph(_ stored: MaximizeLength) -> String {
        switch stored {
        case .points(let points):
            return SettingsValueReadout.points(points)
        case .fraction(let fraction):
            return FractionChips.shares.first {
                FractionChips.matches(fraction, $0.value)
            }?.glyph ?? SettingsValueReadout.percent(fraction)
        }
    }

    /// What VoiceOver reads for `stored`: a percent, or a length in
    /// words, since "pt" reads as letters (#3460).
    static func spoken(_ stored: MaximizeLength) -> String {
        switch stored {
        case .points(let points):
            return L(
                "layout_defaults.maximize.points.ax",
                "%1$@ points",
                SettingsValueReadout.trimmed(points)
            )
        case .fraction(let fraction):
            return SettingsValueReadout.percent(fraction)
        }
    }
}
