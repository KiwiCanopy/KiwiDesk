import KiwiDeskCore
import SwiftUI

/// The read-only shortcuts reference panel (#326): a live mirror
/// of the active key layer's bindings, grouped into Controls /
/// Apps / Inactive / Custom bands, in that drawn order (#820).
/// No editing — rebinding stays in Settings, which
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

    // MARK: - Layer label

    /// The active layer's name, centered in the footer and shown only
    /// for a non-default layer — the default is the implicit case. It
    /// sits in the footer rather than a top header so it costs no
    /// vertical space above the bands.
    @ViewBuilder private var layerLabel: some View {
        if let name = reference?.layerName,
            name != KeyLayer.defaultName
        {
            // Capsule treatment (the Shortcuts editor's layer-chip
            // vocabulary) so it reads as state, not chrome — it's the
            // only layer indicator now. Bounded + truncated so a long
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
                    inactive(reference.inactive)
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

    /// The Inactive band (#820): shortcuts whose target Space has
    /// left the current list. Dimmed as a block — like Settings'
    /// own section (#92) — so they read as parked rather than as
    /// part of the live list, and captioned, since a dimmed row
    /// that says nothing is a dead end. Sits above Custom because
    /// these are seeded defaults, not user-authored Lua.
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
                    // Outside the dimmed subtree: the dim says an
                    // answer exists, and withholding it there is
                    // the dead end `GreyOut` was ruled against.
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
    /// of the surfaces.
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

    /// Empty-state: a layer with nothing bound, or a config the
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
        .overlay(alignment: .center) { layerLabel }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
