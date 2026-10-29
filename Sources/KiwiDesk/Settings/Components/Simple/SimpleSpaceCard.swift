import AppKit
import KiwiDeskCore
import SwiftUI

/// One Space as a card (#2777 rulings 8–9): every part the Space
/// row has — the grip, the identifier chip, the name, the Customize
/// badge, "Pin offline", the Screen menu on two or more screens and
/// the trash — around a picture of the Space that is also its
/// Layout menu's face.
struct SimpleSpaceCard: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var reorder: SpaceReorder
    let space: SpaceID
    let notice: SpaceNameNotice?
    let onNotice: (SpaceNameNotice?) -> Void
    let onDelete: () -> Void
    @State private var faceHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                SpaceDragHandle(model: model, reorder: reorder, space: space)
                IconPicker(
                    icon: model.spaceIconBinding(space),
                    preview: .chip,
                    emptyText: model.spaceIdentifierText(space)
                )
                SpaceNameField(
                    space: space,
                    isAvailable: { !model.takenSpaceNames.contains($0) },
                    onRename: {
                        model.config.renameSpace(from: space, to: $0)
                    },
                    onNotice: onNotice
                )
                if hasOverrides {
                    SpaceCustomizeButton(model: model, space: space) {
                        model.openAdvanced(
                            SettingsAnchor(landing: .space(space))
                        )
                    }
                }
            }
            if let notice {
                SpaceNameNoticeCaption(notice: notice)
            }
            SpaceModePictureMenu(model: model, space: space) { face }
            HStack(spacing: 6) {
                SpacePinChip(model: model, space: space, offlineOnly: true)
                if model.offersScreenMenu {
                    SpaceScreenMenu(model: model, space: space)
                }
                Spacer(minLength: 0)
                SpaceDeleteButton(action: onDelete)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: SettingsTheme.sectionRadius)
                .fill(SettingsTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SettingsTheme.sectionRadius)
                .strokeBorder(
                    SettingsTheme.hairline,
                    lineWidth: SettingsTheme.containerStroke
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardLabel)
        .spaceDragLift(space, in: reorder)
    }

    /// The picture over the layout's name: the menu's face, lifted
    /// under the pointer by a neutral fill.
    private var face: some View {
        let mode = model.config.modes(for: [space])[space] ?? .bsp
        return VStack(alignment: .leading, spacing: 6) {
            SimpleSpacePicture(model: model, space: space)
            HStack(spacing: 5) {
                Image(systemName: mode.symbol)
                Text(mode.displayName)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink2)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(faceHovered ? SettingsTheme.chipRest : .clear)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            faceHovered = inside
            // `set()`, never push/pop (gui.md ▸ SwiftUI traps).
            (inside ? NSCursor.pointingHand : .arrow).set()
        }
    }

    /// The card as VoiceOver groups it: the Space and its layout.
    private var cardLabel: String {
        let mode = model.config.modes(for: [space])[space] ?? .bsp
        return L(
            "simple.spaces.card.ax",
            "%1$@, %2$@",
            model.spaceIdentifierText(space) ?? space.raw,
            mode.displayName
        )
    }

    private var hasOverrides: Bool {
        model.config.settings.spaceOverrideCount(for: space) > 0
    }
}
