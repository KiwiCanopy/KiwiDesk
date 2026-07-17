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
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            body(for: reference)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            footer
        }
        .frame(width: 760)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    private var header: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
    }

    /// "Shortcuts" for the default mode; "Shortcuts — <mode>"
    /// while a custom mode is active, so a user always knows which
    /// set they're looking at.
    private var title: String {
        guard let name = reference?.modeName,
            name != KeyMode.defaultName
        else {
            return L("shortcuts.panel.title", "Shortcuts")
        }
        return L(
            "shortcuts.panel.title_mode",
            "Shortcuts — %1$@",
            name
        )
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

    private var footer: some View {
        HStack {
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
