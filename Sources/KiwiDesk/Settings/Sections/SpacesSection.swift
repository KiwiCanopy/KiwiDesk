import AppKit
import KiwiDeskCore
import SwiftUI

/// Profile Spaces management section: list, reorder, modes, and overrides
/// (#68, #678).
struct SpacesSection: View {
    @ObservedObject var model: SettingsModel
    @State private var newSpace = ""
    @State var pendingDelete: SpaceID?
    @State var pendingResetAll: SpaceID?
    @State var dragged: SpaceID?
    @State var dragOrder: [SpaceID]?
    @State var hoveredHandle: SpaceID?
    @State var rowFrames: [SpaceID: CGRect] = [:]
    @State var overridesButtonWidth: CGFloat = 0
    @Environment(\.controlActiveState) var activeState
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion
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
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
            .coordinateSpace(name: Self.listSpace)
            .onPreferenceChange(SpaceRowFrames.self) {
                rowFrames = $0
            }
            .onPreferenceChange(OverridesButtonWidth.self) {
                overridesButtonWidth = $0
            }
        }
        .onChange(of: activeState) { _, now in
            if now != .key, dragged != nil {
                commitDragOrder()
                dragged = nil
            }
        }
    }

    static let listSpace = "spacesList"

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
            addRow
        }
    }

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
                            "Windows from a removed Space "
                                + "land here when you switch "
                                + "profiles."
                        )
                    )
                }
                pinBadge(space)
                Spacer()
                modePicker(space)
                customizeButton(space)
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)
                deleteButton(space)
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
        .rowActions { contextActions(space) }
        .scaleEffect(dragged == space ? 1.02 : 1)
        .shadow(
            color: .black.opacity(dragged == space ? 0.2 : 0),
            radius: 6,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    dragged == space
                        ? SettingsTheme.planeRing : .clear,
                    lineWidth: 1
                )
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

    private var addRow: some View {
        HStack {
            TextField(
                L("spaces.add.placeholder", "New Space name"),
                text: $newSpace
            )
            .textFieldStyle(.roundedBorder)
            Button {
                addSpace()
            } label: {
                Image(systemName: "plus")
            }
            .disabled(!canAdd)
            .settingsActionButton()
            .help(L("spaces.add.help", "Add Space"))
            .accessibilityLabel(L("spaces.add.help", "Add Space"))
        }
    }

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
