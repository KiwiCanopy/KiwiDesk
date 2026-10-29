import AppKit
import KiwiDeskCore
import SwiftUI

/// Profile Spaces management section: list, reorder, modes, and overrides
/// (#68, #678).
struct SpacesSection: View {
    @ObservedObject var model: SettingsModel
    /// Set only for a space that `carriesOverrides` — a plain
    /// empty space still deletes in one click (#205).
    @State var pendingDelete: SpaceID?
    /// Held here, not on the popover, so the dialog outlives the
    /// popover closing (#290).
    @State var pendingResetAll: SpaceID?
    /// The list's drag-to-reorder, shared with Simple's rows.
    @StateObject var reorder = SpaceReorder(listSpace: "spacesList")
    /// The refusal caption each row's name field reports (#1623).
    @State var renameNotices: [SpaceID: SpaceNameNotice] = [:]
    @Environment(\.controlActiveState) var activeState
    /// The pushed editor's back crumb and the row to return to on
    /// pop (#678 Phase 4 pass 10); wired in `+Overrides` and
    /// `+Customize`, which carry the argument.
    @FocusState var overridesBackFocused: Bool
    @FocusState var returningRow: SpaceID?

    var body: some View {
        Group {
            if let space = editingSpace {
                overridesEditor(space)
            } else {
                spaceList
            }
        }
        // On the container present in both branches: the dialog
        // must outlive the surface that requested it (#290).
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: deleteConfirmPresented,
            presenting: pendingDelete
        ) { space in
            deleteConfirmActions(space)
        } message: { _ in
            Text(deleteConfirmMessage)
        }
        .confirmationDialog(
            resetAllConfirmTitle,
            isPresented: resetAllConfirmPresented,
            presenting: pendingResetAll
        ) { space in
            resetAllConfirmActions(space)
        } message: { _ in
            Text(resetAllConfirmMessage)
        }
    }

    /// Pushed per-space override editor or list fallback (#678).
    private var editingSpace: SpaceID? {
        guard
            let space = model.nav.spaceOverridesFocus,
            model.config.spaces.contains(space)
        else { return nil }
        return space
    }

    private var spaceList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                spacesSection
            }
            .padding(.horizontal, SettingsMetrics.paneInset)
            .settingsPageBottom()
            .spaceReorderList(reorder)
        }
        .onChange(of: activeState) { _, now in
            // Deactivating mid-drag abandons the gesture with no
            // onEnded — commit so the list cannot keep showing an
            // unsaved reorder (#299).
            if now != .key { reorder.abandon(to: model) }
        }
    }

    private var spacesSection: some View {
        SettingsSection(SettingsCatalog.spaces.spacesCard) {
            Text(spacesCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(fallbackCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.config.spaces.isEmpty {
                Text(emptyCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(displayedSpaces, id: \.raw) { space in
                spaceRow(space)
            }
            SpaceAddRow(spaces: takenSpaces) {
                model.config.spaces.append($0)
            }
            liveOnlyRows
            CrossReferenceRow(
                prose: Self.shortcutsProse,
                linkTitle: SettingsDestination.shortcuts.title,
                destination: .shortcuts
            )
        }
    }

    var takenSpaces: [SpaceID] { model.takenSpaceNames }

    private func spaceRow(_ space: SpaceID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                dragHandle(space)
                IconPicker(
                    icon: model.spaceIconBinding(space),
                    preview: .chip
                )
                SpaceNameField(
                    space: space,
                    isAvailable: { !takenSpaces.contains($0) },
                    onRename: {
                        model.config.renameSpace(
                            from: space,
                            to: $0
                        )
                    },
                    onNotice: { renameNotices[space] = $0 }
                )
                if model.config.fallbackSpace == space {
                    BadgeChip(
                        label: L(
                            "spaces.fallback_badge",
                            "Fallback"
                        )
                    )
                    .help(
                        L(
                            "spaces.fallback_badge.help",
                            "Windows from a removed Space "
                                + "land here when you switch "
                                + "profiles."
                        )
                    )
                }
                SpacePinChip(model: model, space: space)
                Spacer()
                SpaceModeMenu(model: model, space: space)
                    // Focused row target for navigation returns
                    // (#678 Phase 4, #812).
                    .focused($returningRow, equals: space)
                customizeButton(space)
                // Danger zone: set the destructive delete apart
                // so the trash can't be hit reaching for the
                // picker or Customize (#205).
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)
                deleteButton(space)
            }
            // Under the row, not the field: stacked in the HStack
            // it would pull the field off the row's centre line.
            if let notice = renameNotices[space] {
                SpaceNameNoticeCaption(notice: notice)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(SettingsTheme.sunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    SettingsTheme.hairline
                )
        )
        // One builder, three channels (#845): the context menu is
        // the ONLY site for Move Up/Down/Make Fallback, so a bare
        // channel here was pointer-only for those verbs.
        .rowActions { contextActions(space) }
        .spaceDragLift(space, in: reorder)
    }
}
