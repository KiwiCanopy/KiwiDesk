import KiwiDeskCore
import SwiftUI

/// The name under the card, its line and the key hint (#3038); after
/// ⌘S the name is a field holding the quick name, selected, which ↩
/// renames through and Esc keeps (ui-designer consult 2026-11-26).
struct LookPickerCaption: View {
    @ObservedObject var model: LookPickerModel
    let geometry: LookPickerGeometry
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            name
            if let entry = model.selected {
                Text(LookPickerText.subtitle(entry, worn: worn))
                    .font(.system(size: 15, weight: .medium))
                    .opacity(0.75)
                    .accessibilityHidden(true)
            }
            Text(
                LookPickerText.hint(
                    model.selected,
                    worn: worn,
                    naming: model.isNaming
                )
            )
            .font(.system(size: 15, weight: .medium))
            .opacity(0.8)
            .padding(.top, 6)
            .accessibilityHidden(true)
        }
        .foregroundStyle(SettingsTheme.plateInk)
        .shadow(color: SettingsTheme.visionVeil.opacity(0.7), radius: 14, y: 2)
        .frame(width: geometry.screen.width)
        .offset(y: geometry.nameTop)
    }

    private var worn: Bool { model.selection == model.wornIndex }

    @ViewBuilder
    private var name: some View {
        if let draft = model.nameDraft {
            TextField(
                "",
                text: Binding(
                    get: { draft },
                    set: { model.nameDraft = $0 }
                )
            )
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(size: geometry.nameSize, weight: .bold))
            .frame(maxWidth: geometry.card.width)
            .focused($nameFocused)
            .onAppear { nameFocused = true }
            // The card speaks for the look; the field, open after
            // ⌘S, names what it edits.
            .accessibilityLabel(LookPickerText.nameField)
        } else {
            Text(model.selected.map(LookPickerText.name) ?? "")
                .font(.system(size: geometry.nameSize, weight: .bold))
                .lineLimit(1)
                .accessibilityHidden(true)
        }
    }
}
