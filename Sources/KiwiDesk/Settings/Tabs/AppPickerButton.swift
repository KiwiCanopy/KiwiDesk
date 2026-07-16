import AppKit
import KiwiDeskCore
import SwiftUI

/// The searchable app picker (#263), the sibling of
/// `IconPicker` for the two app choosers (`AppSelector` in App
/// Rules, `appMenu` in Open Applications). A native `Menu` over
/// 150–300 installed apps only offers prefix type-to-select; a
/// popover with a substring search over a lazy icon list is the
/// macOS move for long app lists. The persistent escape row
/// beneath the search (Custom… / Other…) survives filtering.
///
/// Apps are identified by lower-cased bundle id and shown by
/// localized name (see `AppRef`); the caller stores the id the
/// `onPick` app carries. Icons come from the `@MainActor`
/// `AppIconCache`, not off `InstalledApp`.
struct AppPickerButton: View {
    /// Shown on the trigger when nothing is chosen yet.
    let placeholder: String
    /// The current selection's display name, or nil for none.
    let selection: String?
    /// Floor width for the trigger — just enough for the
    /// "Choose app…" placeholder; it hugs longer names. A caller
    /// that needs a fixed column (Open Applications) wraps the
    /// button in its own `.frame(width:)` instead.
    var minWidth: CGFloat = 110
    let onPick: (KeybindingCatalog.InstalledApp) -> Void
    /// The persistent escape row: its label (Custom… / Other…)
    /// and the action it triggers (reveal a field / open a
    /// panel). Runs after the popover dismisses.
    let escapeLabel: String
    let onEscape: () -> Void

    @State private var showing = false
    @State private var search = ""

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 4) {
                Text(selection ?? placeholder)
                    .lineLimit(1)
                // Absorbs the slack between text and chevron, so
                // the chevron pins to the trailing edge (native
                // pop-up look) instead of floating mid-button when
                // the frame is wider than the content.
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: minWidth, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .onAppear {
            AppIconCache.shared.warm()
            // Warm the heavy part — the one-time Spotlight scan of
            // ~150–300 disk apps — off the main thread, so the
            // first open mostly finds it ready. Only the disk scan
            // moves off-main: it touches no AppKit (FileManager /
            // Bundle / NSMetadataItem only). The running-app union
            // in `installedAppsSnapshot` still reads
            // `NSWorkspace` on the main thread at first open, but
            // that part is cheap.
            Task.detached {
                _ = KeybindingCatalog.diskAppIconPaths
            }
        }
        .popover(isPresented: $showing) { popover }
    }

    // MARK: - Popover

    private var popover: some View {
        VStack(spacing: 8) {
            TextField(
                L("app_picker.search.placeholder", "Search apps"),
                text: $search
            )
            .textFieldStyle(.roundedBorder)
            escapeRow
            Divider()
            // Eager `VStack`, not `LazyVStack`: a lazy stack
            // renders blank in a popover until a state change
            // (a keystroke) forces relayout. Icons come warmed
            // from the cache, so building every row up front is
            // cheap.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { app in
                        row(app)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
        }
        .padding(12)
        .frame(width: 280, height: 360)
    }

    /// The escape hatch, kept above the list so it never scrolls
    /// out of reach and survives filtering.
    private var escapeRow: some View {
        Button {
            showing = false
            // Let SwiftUI process the dismiss before the escape
            // action runs — `Other…` opens a modal `NSOpenPanel`
            // that would otherwise block with the popover still
            // on screen.
            DispatchQueue.main.async { onEscape() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.circle")
                    .frame(width: AppIconCache.side)
                Text(escapeLabel)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .rowHoverHighlight()
    }

    private func row(
        _ app: KeybindingCatalog.InstalledApp
    ) -> some View {
        Button {
            onPick(app)
            showing = false
        } label: {
            HStack(spacing: 8) {
                Image(
                    nsImage: AppIconCache.shared.icon(
                        forBundleID: app.bundleID
                    )
                )
                .resizable()
                .frame(
                    width: AppIconCache.side,
                    height: AppIconCache.side
                )
                Text(app.name)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .rowHoverHighlight()
    }

    private var filtered: [KeybindingCatalog.InstalledApp] {
        AppPickerFilter.matching(
            KeybindingCatalog.installedAppsSnapshot,
            query: search
        )
    }
}

/// The picker's substring filter, split out pure so it is unit
/// testable without the view. Case- and diacritic-insensitive
/// (`localizedStandardContains`, the app's one search-matching
/// vocabulary — shared with the sidebar search) on the
/// localized name OR the bundle id — the latter keeps an app
/// findable by its English/habitual name (typing "preview"
/// matches `com.apple.preview` even when it's shown localized
/// as "Vorschau"). An empty (or whitespace) query keeps every
/// app.
enum AppPickerFilter {
    static func matching(
        _ apps: [KeybindingCatalog.InstalledApp],
        query: String
    ) -> [KeybindingCatalog.InstalledApp] {
        let query = query.trimmed
        guard !query.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedStandardContains(query)
                || $0.bundleID.localizedStandardContains(
                    query
                )
        }
    }
}
