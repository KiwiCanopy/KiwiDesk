import AppKit
import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Spaces (#68 §3.2/§3.3): the profile's space
/// list — rename, reorder (drag or context menu), pick a layout
/// mode (with its glyph), designate the fallback space, and
/// tune per-space overrides inline on each row.
struct SpacesSection: View {
    @ObservedObject var model: SettingsModel
    @State private var newSpace = ""
    /// Rows with an open "Customize" expander.
    @State private var expanded: Set<SpaceID> = []
    // Drag-reorder state, shared with the handle/gesture
    // extension (`SpacesSection+Drag.swift`), hence not
    // `private` (which is file-scoped).
    /// The space being handle-dragged, if any.
    @State var dragged: SpaceID?
    /// The handle currently under the pointer — tracked even
    /// mid-drag (when hover no longer drives the cursor), so
    /// drag end and row teardown can restore the right cursor.
    @State var hoveredHandle: SpaceID?
    /// Each row's frame in list space, for retargeting the
    /// drag — measured via preference, so variable-height
    /// rows (open expanders) stay accurate.
    @State var rowFrames: [SpaceID: CGRect] = [:]

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
            ForEach(model.config.spaces, id: \.raw) { space in
                spaceRow(space)
            }
            addRow
        }
    }

    private var spacesCaption: String {
        L(
            "spaces.caption",
            "Each space has its own layout. Add spaces "
                + "here; they appear in the shortcut and "
                + "app-rule lists too. Drag rows to "
                + "reorder."
        )
    }

    private var fallbackCaption: String {
        L(
            "spaces.fallback_caption",
            "When you switch profiles, windows from a "
                + "space the new profile doesn't have "
                + "land in its fallback space (the first "
                + "space when none is chosen)."
        )
    }

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
                expandButton(space)
                Button {
                    removeSpace(space)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            if expanded.contains(space) {
                SpaceOverrideRows(model: model, space: space)
                    .padding(.leading, 24)
                    .padding(.bottom, 4)
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

    private func modePicker(_ space: SpaceID) -> some View {
        Picker("", selection: modeBinding(space)) {
            ForEach(LayoutMode.allCases, id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.glyph)
                    .tag(mode)
            }
        }
        .labelsHidden()
        .controlSize(.large)
        .frame(width: 150)
    }

    private func expandButton(_ space: SpaceID) -> some View {
        Button {
            if expanded.contains(space) {
                expanded.remove(space)
            } else {
                expanded.insert(space)
            }
        } label: {
            Image(
                systemName: expanded.contains(space)
                    ? "chevron.down" : "slider.horizontal.3"
            )
        }
        .buttonStyle(.borderless)
        .help(
            L(
                "spaces.customize.help",
                "Customize this space"
            )
        )
    }

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
            removeSpace(space)
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

    private func removeSpace(_ space: SpaceID) {
        // Clears the list entry AND every reference (pin,
        // Main role, fallback, per-space settings maps) — a
        // leftover reference would resurrect the space on the
        // next profile load (#68 review).
        model.config.removeSpace(space)
        expanded.remove(space)
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

    /// Setting a space to the default `bsp` removes its entry
    /// (the writer treats absent as `bsp`).
    private func modeBinding(
        _ space: SpaceID
    ) -> Binding<LayoutMode> {
        Binding(
            get: { model.config.spaceModes[space] ?? .bsp },
            set: { mode in
                model.config.spaceModes[space] =
                    mode == .bsp ? nil : mode
            }
        )
    }
}
