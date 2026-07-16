import AppKit
import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Spaces (#68 §3.2/§3.3): the profile's space
/// list — rename, reorder (drag or context menu), pick a layout
/// mode (with its glyph), designate the fallback space, and
/// tune per-space overrides in a Customize popover (#205).
struct SpacesSection: View {
    @ObservedObject var model: SettingsModel
    @State private var newSpace = ""
    /// The one row whose "Customize" popover is open, if any.
    /// A single slot (not a set) makes the popover its own
    /// accordion — opening one row closes any other (#205).
    @State var customizing: SpaceID?
    /// A space awaiting delete confirmation — set only for a
    /// space that `carriesOverrides`, so a plain empty space
    /// still deletes in one click (#205).
    @State var pendingDelete: SpaceID?
    /// A space awaiting `Reset All Layout Overrides` confirmation
    /// (#290). Held here, not on the popover, so the dialog
    /// outlives the popover closing — same shape as
    /// `pendingDelete`. The override rows set it through a binding.
    @State var pendingResetAll: SpaceID?
    // Drag-reorder state, shared with the handle/gesture
    // extension (`SpacesSection+Drag.swift`), hence not
    // `private` (which is file-scoped).
    /// The space being handle-dragged, if any.
    @State var dragged: SpaceID?
    /// The live display order *during* a drag — seeded from the
    /// model on drag start, reordered locally on each threshold
    /// cross, and written back to `model.config.spaces` once on
    /// drop. Keeps the per-swap cost to a cheap array move instead
    /// of a `@Published`/profile write (which re-evaluated the
    /// whole config every crossing, #299). `nil` when idle: the
    /// list then renders straight from the model.
    @State var dragOrder: [SpaceID]?
    /// The handle currently under the pointer — tracked even
    /// mid-drag (when hover no longer drives the cursor), so
    /// drag end and row teardown can restore the right cursor.
    @State var hoveredHandle: SpaceID?
    /// Each row's frame in list space, for retargeting the
    /// drag — measured via preference so the retarget reads live
    /// row positions (e.g. after a reorder) rather than stale
    /// ones.
    @State var rowFrames: [SpaceID: CGRect] = [:]
    /// The widest Overrides-button label on screen, measured (never
    /// guessed) so every row's button locks to one column width
    /// that stays correct across locales and counts (#290).
    @State var overridesButtonWidth: CGFloat = 0
    /// Whether this window is key/active — watched so a drag the
    /// app deactivates out of (Cmd-Tab, a mouse-up delivered to
    /// another app) still commits, since that path reaches
    /// neither `onEnded` nor `onDisappear` (#299).
    @Environment(\.controlActiveState) var activeState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                spacesSection
            }
            .padding(16)
            .coordinateSpace(name: Self.listSpace)
            .onPreferenceChange(SpaceRowFrames.self) {
                rowFrames = $0
            }
            .onPreferenceChange(OverridesButtonWidth.self) {
                overridesButtonWidth = $0
            }
        }
        .onChange(of: activeState) { _, now in
            // The app deactivating mid-drag abandons the gesture
            // without an onEnded — commit the live order so the
            // list can't keep showing an unsaved reorder (#299).
            if now != .key, dragged != nil {
                commitDragOrder()
                dragged = nil
            }
        }
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

    static let listSpace = "spacesList"

    private var spacesSection: some View {
        SettingsSection(L("spaces.title", "Spaces")) {
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
            addRow
        }
    }

    // Captions live in `SpacesSection+Captions.swift`.

    // MARK: - Rows

    private func spaceRow(_ space: SpaceID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                dragHandle(space)
                IconPicker(
                    icon: iconBinding(space),
                    preview: .chip
                )
                SpaceNameField(
                    space: space,
                    isAvailable: {
                        !model.config.spaces.contains($0)
                    },
                    onRename: {
                        model.config.renameSpace(
                            from: space,
                            to: $0
                        )
                    }
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
                            "Windows from a removed space "
                                + "land here when you switch "
                                + "profiles."
                        )
                    )
                }
                Spacer()
                modePicker(space)
                customizeButton(space)
                // Danger zone: a divider and breathing room set
                // the destructive delete apart from the mode
                // picker and Overrides, so the trash can't be
                // hit reaching for either (#205).
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)
                deleteButton(space)
            }
        }
        .padding(8)
        // Each space is a bordered card: the rows read as
        // grabbable tiles, not table lines.
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    Color(nsColor: .separatorColor)
                )
        )
        .contextMenu { contextActions(space) }
        // Lifted while dragged: the row itself is what moves
        // (no system ghost), stepping slot to slot — it never
        // leaves the column.
        .scaleEffect(dragged == space ? 1.02 : 1)
        .shadow(
            color: .black.opacity(dragged == space ? 0.2 : 0),
            radius: 6,
            y: 2
        )
        .zIndex(dragged == space ? 1 : 0)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SpaceRowFrames.self,
                    value: [
                        space: proxy.frame(
                            in: .named(Self.listSpace)
                        )
                    ]
                )
            }
        )
    }

    // `modePicker` and its binding live in
    // `SpacesSection+ModePicker.swift` (#123 file-size split).

    // `customizeButton` (the popover anchor), the delete
    // confirmation, and the empty-state live in
    // `SpacesSection+Customize.swift` (#205 file-size split).

    /// Keyboard-reachable equivalents of the drag/badge
    /// affordances (the §3.13 accessibility pattern).
    @ViewBuilder
    private func contextActions(_ space: SpaceID) -> some View {
        if model.config.fallbackSpace == space {
            Button(
                L("spaces.context.clear_fallback", "Clear Fallback")
            ) {
                model.config.fallbackSpace = nil
            }
        } else {
            Button(
                L("spaces.context.make_fallback", "Make Fallback")
            ) {
                model.config.fallbackSpace = space
            }
        }
        Divider()
        Button(L("spaces.context.move_up", "Move Up")) {
            nudge(space, by: -1)
        }
        .disabled(index(of: space) == 0)
        Button(L("spaces.context.move_down", "Move Down")) {
            nudge(space, by: 1)
        }
        .disabled(
            index(of: space)
                == model.config.spaces.count - 1
        )
        Divider()
        Button(
            L("spaces.context.delete", "Delete"),
            role: .destructive
        ) {
            requestRemove(space)
        }
    }

    private var addRow: some View {
        HStack {
            TextField(
                L("spaces.add.placeholder", "New space name"),
                text: $newSpace
            )
            .textFieldStyle(.roundedBorder)
            Button {
                addSpace()
            } label: {
                Image(systemName: "plus")
            }
            .disabled(!canAdd)
            // Icon-only, like its sibling icon buttons (#94).
            .help(L("spaces.add.help", "Add space"))
        }
    }

    // MARK: - Mutations

    private var canAdd: Bool {
        let name = newSpace.trimmed
        return !name.isEmpty
            && !model.config.spaces.contains { $0.raw == name }
    }

    private func addSpace() {
        guard canAdd else { return }
        model.config.spaces.append(SpaceID(newSpace.trimmed))
        newSpace = ""
    }

    /// The actual delete, reached either straight from
    /// `requestRemove` (space carries nothing) or after the
    /// confirmation dialog. Clears the list entry AND every
    /// reference (pin, Main role, fallback, per-space settings
    /// maps) — a leftover reference would resurrect the space on
    /// the next profile load (#68 review).
    func removeSpace(_ space: SpaceID) {
        model.config.removeSpace(space)
        if customizing == space { customizing = nil }
    }

    private func index(of space: SpaceID) -> Int {
        model.config.spaces.firstIndex(of: space) ?? 0
    }

    private func nudge(_ space: SpaceID, by delta: Int) {
        let from = index(of: space)
        let to = from + delta
        guard model.config.spaces.indices.contains(to) else {
            return
        }
        model.config.spaces.swapAt(from, to)
    }

    /// The space's optional recognition icon (#68 §6.5):
    /// empty clears the sparse `space.icon` entry.
    private func iconBinding(
        _ space: SpaceID
    ) -> Binding<String> {
        Binding(
            get: {
                model.config.settings.spaceIcons[space] ?? ""
            },
            set: {
                model.config.settings.spaceIcons[space] =
                    $0.isEmpty ? nil : $0
            }
        )
    }

}
