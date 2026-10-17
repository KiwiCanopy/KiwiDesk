import KiwiDeskCore
import SwiftUI

/// The Tile picker's rows (#2071): each app the guess floated a
/// window of, named as Core tracks it, its open guessed windows'
/// titles as a caption. Picking is the add (#1172).
struct GuessedAppRows: View {
    let apps: [GuessedFloatApp]
    let onPick: (KeybindingCatalog.InstalledApp) -> Void
    /// The bundle id the picker's cursor sits on (`DropdownCursor`).
    var cursor: String?
    /// Every pointer event over a row, for `DropdownCursor.hover`.
    var onPoint: (String) -> Void = { _ in }

    var body: some View {
        if apps.isEmpty {
            Text(Self.empty)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
        } else if apps.count <= Self.unscrolled {
            list
        } else {
            ScrollView { list }
                .frame(height: 280)
        }
    }

    /// The rows a popover shows before it scrolls.
    static let unscrolled = 8

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(apps, id: \.bundleID) { row($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ app: GuessedFloatApp) -> some View {
        let onCursor = app.bundleID == cursor
        return Button {
            onPick(.init(bundleID: app.bundleID, name: app.name))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(
                    nsImage: AppIconCache.shared.icon(
                        forBundleID: app.bundleID
                    )
                )
                .resizable()
                .frame(width: AppIconCache.side, height: AppIconCache.side)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .lineLimit(1)
                    if let caption = Self.caption(app.titles) {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(
                                DropdownRowStyle.secondaryInk(onCursor)
                            )
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .foregroundStyle(DropdownRowStyle.ink(onCursor))
            .contentShape(Rectangle())
            .padding(.vertical, 3)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .dropdownCursorRow(onCursor) { onPoint(app.bundleID) }
    }

    /// The first open window's title, and how many more; nil for
    /// an app with none open.
    static func caption(_ titles: [String]) -> String? {
        guard let first = titles.first else { return nil }
        let name =
            first.isEmpty
            ? L("app_rules.tile.picker.untitled", "Untitled window")
            : first
        guard titles.count > 1 else { return name }
        return L(
            "app_rules.tile.picker.windows",
            "%1$@ and more: %2$d",
            name,
            titles.count - 1
        )
    }

    static var empty: String {
        L(
            "app_rules.tile.picker.empty",
            "No window has floated automatically yet."
        )
    }

    static var hint: String {
        L(
            "app_rules.tile.picker.hint",
            "Shows apps that floated a window automatically since "
                + "KiwiDesk started. To tile another, open that "
                + "window, then come back."
        )
    }
}
