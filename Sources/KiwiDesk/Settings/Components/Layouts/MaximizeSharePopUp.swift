import KiwiDeskCore
import SwiftUI

/// A Maximize share's pop-up (#3062, #3460): the five fractions,
/// each with its length on this row's screen, then a stored value
/// outside them as a checked item, then "Custom…", which opens an
/// anchored percent-or-points popover. Closed and open it shows the
/// fraction first and the length greyed after it (#3488 ▸ option
/// E). Layout Defaults' shape rows and a Space's own rows (#3090)
/// both draw it.
struct MaximizeSharePopUp: View {
    @Binding var value: MaximizeLength
    /// The axis this share sizes the other of: a Maximize Height's
    /// share is a width.
    let axis: MaximizeAxis
    /// A screen of this row's shape, which the menu's lengths and
    /// the unit flip read; nil with none.
    let region: MaximizeRegion?
    /// The pop-up's spoken name.
    let label: String
    /// The Custom popover's column name.
    let column: String
    /// The open Custom popover (#3062).
    @State private var custom: MaximizeCustomRequest?
    @State private var anchor = PullDownAnchor()

    var body: some View {
        Button(action: open) {
            HStack(spacing: 6) {
                Text(Self.glyph(value))
                let detail = Self.detail(
                    value,
                    axis: axis,
                    region: region
                )
                if !detail.isEmpty {
                    Text(detail).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .monospacedDigit()
        }
        .settingsPopUpTrigger()
        .controlSize(.large)
        .fixedSize()
        // The button's own view, so the menu opens in ITS window.
        .background(PullDownAnchorView(anchor: anchor))
        .accessibilityLabel(label)
        .accessibilityValue(
            Self.spoken(value, axis: axis, region: region)
        )
        .accessibilityHint(L("pull_down.ax_hint", "Opens a menu."))
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

    /// Opens the menu over the button; a share writes, Custom…
    /// opens its popover.
    private func open() {
        guard let view = anchor.view, view.window != nil else { return }
        MaximizeShareMenu.present(
            MaximizeShareMenu.entries(value, axis: axis, region: region),
            checked: Self.selection(value),
            from: view
        ) { entry in
            switch entry {
            case .share(let share, _, _):
                value = share
            case .custom:
                custom = MaximizeCustomRequest(
                    stored: value,
                    axis: axis,
                    region: region
                )
            case .divider:
                break
            }
        }
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

    /// The greyed length `share` fills on `region`, empty with no
    /// screen or for a length, which its title already states.
    static func detail(
        _ share: MaximizeLength,
        axis: MaximizeAxis,
        region: MaximizeRegion?
    ) -> String {
        guard let region, share.fraction != nil else { return "" }
        return SettingsValueReadout.points(
            region.points(of: share, axis: axis)
        )
    }

    /// What VoiceOver reads for the closed button: `stored`, then
    /// the length it fills on `region` where the button draws one,
    /// so what is drawn is what is spoken (#3488).
    static func spoken(
        _ stored: MaximizeLength,
        axis: MaximizeAxis,
        region: MaximizeRegion?
    ) -> String {
        guard let region, stored.fraction != nil else {
            return spoken(stored)
        }
        return L(
            "layout_defaults.maximize.share.ax",
            "%1$@, %2$@",
            spoken(stored),
            spoken(.points(region.points(of: stored, axis: axis)))
        )
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
