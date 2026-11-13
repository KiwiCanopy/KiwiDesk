import KiwiDeskCore
import SwiftUI

/// The picker's trigger: the row's one container (#3162, #3241).
extension SequenceActionMenu {
    @ViewBuilder var trigger: some View {
        if face.kind == .custom, let onEditLua {
            // Opens the Lua editor, not a menu (#3241).
            Button(action: onEditLua) {
                HStack(spacing: 4) {
                    if marksKind {
                        Image(systemName: Self.luaSymbol)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                    if marksKind {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption2)
                            .foregroundStyle(SettingsTheme.ink2)
                            .accessibilityHidden(true)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(SequenceDashedStyle())
        } else {
            Button {
                request = SequencePickRequest(id: face.id)
            } label: {
                HStack(spacing: 4) {
                    appIcon
                    commandGlyph
                    Text(title).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .settingsPopUpTrigger()
        }
    }

    /// An app key's icon, as the Apps section's rows draw it.
    @ViewBuilder var appIcon: some View {
        if let bundleID {
            Image(nsImage: AppIconCache.shared.icon(forBundleID: bundleID))
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
    }

    /// An action's catalogue glyph, as its Shortcuts row draws it.
    @ViewBuilder var commandGlyph: some View {
        if marksKind, bundleID == nil,
            let command = catalog.command(running: face.lua),
            let glyph = ShortcutsReferenceBuilder.icon(for: command)
        {
            IconGlyphLabel(icon: glyph)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
    }

    /// The app an app key opens; nil for every other key.
    var bundleID: String? {
        guard face.kind == .application else { return nil }
        return KeybindingCatalog.appBundleID(from: face.lua)
    }

    /// The action's name, "Lua…" for the user's own, the app's name
    /// for an app key, the face's own words for a family, "Choose…"
    /// for none yet.
    var title: String {
        if let title = face.title { return title }
        if face.kind == .custom {
            return face.desc.trimmed.isEmpty ? Self.luaLabel : face.desc
        }
        if let bundleID {
            return KeybindingCatalog.displayName(forBundleID: bundleID)
        }
        if let command = catalog.command(running: face.lua) {
            return command.resolvedLabel
        }
        return face.lua.isEmpty
            ? L("shortcuts.sequence.choose", "Choose…") : face.lua
    }
}
