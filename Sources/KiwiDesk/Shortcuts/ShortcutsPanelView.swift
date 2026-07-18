import KiwiDeskCore
import SwiftUI

/// The read-only shortcuts reference panel (#326): a live mirror
/// of the active key mode's bindings, grouped into Controls / Apps
/// / Custom bands. No editing — rebinding stays in Settings, which
/// the single footer button bridges to. `reference` is nil when
/// live shortcuts can't be read (config owned by init.lua, or the
/// engine isn't running).
struct ShortcutsPanelView: View {
    let reference: ShortcutsReference?
    /// The combo bound to open this panel (native glyphs), or nil
    /// when unbound (#330). Drives the footer hint: the same key
    /// that opened it also closes it, so it leads the copy.
    let dismissCombo: String?
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

    // MARK: - Mode label

    /// The active mode's name, centered in the footer and shown only
    /// for a non-default mode — the default is the implicit case. It
    /// sits in the footer rather than a top header so it costs no
    /// vertical space above the bands.
    @ViewBuilder private var modeLabel: some View {
        if let name = reference?.modeName,
            name != KeyMode.defaultName
        {
            // Capsule treatment (the Shortcuts editor's mode-chip
            // vocabulary) so it reads as state, not chrome — it's the
            // only mode indicator now. Bounded + truncated so a long
            // custom name can't collide with the hint or the button.
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
                    custom(reference.custom)
                }
                .padding(20)
            }
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

    /// Empty-state: a mode with nothing bound, or a config the
    /// panel can't read live. Distinct messages, same quiet frame.
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

    /// Bound → lead with the live open-combo ("⌥␣ or Esc to close"),
    /// the two dismissals worth the characters — the same key that
    /// opened it is the most self-evident way to close it, and it
    /// teaches a mouse-opener the shortcut. Unbound → the generic
    /// hint, which keeps "click away" (#330, #326).
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

    private var footer: some View {
        HStack {
            // A chromeless panel has no titlebar to teach dismissal,
            // so the one non-obvious interaction gets a quiet hint on
            // the idle side, opposite the action button.
            Text(dismissHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onEdit) {
                Text(
                    L(
                        "shortcuts.panel.edit_in_settings",
                        "Edit in Settings…"
                    )
                )
            }
        }
        // Centered in the full footer width, independent of the
        // hint / button widths on either side.
        .overlay(alignment: .center) { modeLabel }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
