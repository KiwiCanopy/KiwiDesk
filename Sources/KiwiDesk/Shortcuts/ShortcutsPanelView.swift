import KiwiDeskCore
import SwiftUI

/// Read-only shortcuts cheat sheet panel (#326, #820).
struct ShortcutsPanelView: View {
    let reference: ShortcutsReference?
    /// Bound dismiss combo string, or nil when unbound (#330).
    let dismissCombo: String?
    /// Whether the content clipped, from the controller's own
    /// clamp — never re-derived here (#1292).
    let overflows: Bool
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            body(for: reference)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            footer
        }
        .frame(width: 760)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - Layer label

    /// Layer name chip for non-default key layers (`KeyLayer.defaultName`).
    @ViewBuilder private var layerLabel: some View {
        if let name = reference?.layerName,
            name != KeyLayer.defaultName
        {
            Text(name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.2))
                )
                .frame(maxWidth: 280)
        }
    }

    // MARK: - Body

    @ViewBuilder private func body(
        for reference: ShortcutsReference?
    ) -> some View {
        if let reference, !reference.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    controls(reference.controls)
                    apps(reference.apps)
                    inactive(reference.inactive)
                    custom(reference.custom)
                }
                .padding(20)
            }
            // VoiceOver lands on the scroll view as a bare
            // "scroll area" before interacting into it
            // (`SettingsDetailPanel`, #812).
            .accessibilityLabel(
                L("shortcuts.panel.ax_label", "Shortcuts reference")
            )
        } else {
            placeholder(unavailable: reference == nil)
        }
    }

    @ViewBuilder private func controls(
        _ subgroups: [ShortcutSubgroup]
    ) -> some View {
        if !subgroups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ShortcutsBandHeader(
                    title: L("shortcuts.panel.controls", "Controls")
                )
                ControlsBand(subgroups: subgroups)
            }
        }
    }

    @ViewBuilder private func apps(
        _ rows: [ShortcutRow]
    ) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ShortcutsBandHeader(
                    title: L("shortcuts.panel.apps", "Apps")
                )
                AppsBand(rows: rows)
            }
        }
    }

    /// Inactive shortcuts band for missing spaces (`GreyOut`, #92, #820).
    @ViewBuilder private func inactive(
        _ rows: [ShortcutRow]
    ) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ShortcutsBandHeader(
                    title: L(
                        "shortcuts.section.inactive",
                        "Inactive shortcuts"
                    )
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text(inactiveCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(rows) { ShortcutRowView(row: $0) }
                    }
                    .opacity(0.6)
                }
            }
        }
    }

    /// Settings' own section says the same thing and then adds
    /// "rebind or remove them here" — which this panel cannot
    /// offer, so the two captions are deliberately different
    /// strings rather than one shared key that would lie on one
    /// surface.
    private var inactiveCaption: String {
        L(
            "shortcuts.panel.inactive.caption",
            "These target Spaces that are not in the current "
                + "Space list. They still work — pressing one "
                + "recreates its Space — and they come back "
                + "when their Space returns."
        )
    }

    @ViewBuilder private func custom(
        _ rows: [ShortcutRow]
    ) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ShortcutsBandHeader(
                    title: L("shortcuts.panel.custom", "Custom")
                )
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rows) { ShortcutRowView(row: $0) }
                }
            }
        }
    }

    /// Empty state view for unconfigured or Lua-managed setups.
    private func placeholder(unavailable: Bool) -> some View {
        Text(
            unavailable
                ? L(
                    "shortcuts.panel.unavailable",
                    "Shortcuts are managed by your init.lua."
                )
                : L(
                    "shortcuts.panel.empty",
                    "No shortcuts bound yet."
                )
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
    }

    // MARK: - Footer

    /// Dismiss hint text string (#326, #330).
    private var dismissHint: String {
        if let combo = dismissCombo {
            return L(
                "shortcuts.panel.dismiss_hint.bound",
                "%1$@ or Esc to close",
                combo
            )
        }
        return L(
            "shortcuts.panel.dismiss_hint",
            "Esc or click away to close"
        )
    }

    /// Says the list continues, on the one thing that otherwise
    /// says it ends (#1292). Worded rather than positional, so
    /// it stays true at any scroll offset.
    @ViewBuilder private var scrollCue: some View {
        if overflows {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .accessibilityHidden(true)
                Text(
                    L(
                        "shortcuts.panel.scroll_hint",
                        "Scroll for more shortcuts"
                    )
                )
            }
        }
    }

    /// The chip is a SIBLING, not an overlay: a second caption
    /// line widens the leading slot in every locale, and an
    /// overlay would draw the chip on top of it. Only the
    /// captions flex — a second flexible child would halve the
    /// footer and cap the cue at ~208pt beside a wide chip,
    /// which `ru` overruns (#1292).
    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                scrollCue
                Text(dismissHint)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            layerLabel
                .layoutPriority(1)
            Button(action: onEdit) {
                Text(
                    L(
                        "shortcuts.panel.edit_in_settings",
                        "Edit in Settings…"
                    )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
