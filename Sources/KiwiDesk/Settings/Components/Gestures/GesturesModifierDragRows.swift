import KiwiDeskCore
import SwiftUI

/// Mouse & trackpad ▸ On your windows: the modifier drags (#2447
/// ruling 2026-11-08). Two rows, "Move windows from anywhere" and
/// "Resize windows from anywhere", each a modifiers-only recorder
/// and a pop-up for how it starts; the recorder's × turns it off.
/// The draft holds `gui.json`'s values, global to every profile.
struct GesturesModifierDragRows: View {
    @ObservedObject var model: SettingsModel

    private var drags: ModifierDragSettings { model.config.modifierDrag }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(.move)
                .searchAnchored(
                    SettingsCatalog.shortcuts.gestures.children
                        .modifierDragMove
                )
            row(.resize)
                .searchAnchored(
                    SettingsCatalog.shortcuts.gestures.children
                        .modifierDragResize
                )
            Text(Self.caption)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    static var caption: String {
        L(
            "shortcuts.gestures.modifier_drag.caption",
            "Hold the keys and drag inside a window. Resizing follows "
                + "the corner nearest where you grab."
        )
    }

    static func title(_ action: ModifierDragAction) -> String {
        switch action {
        case .move:
            return L(
                "shortcuts.gestures.modifier_drag.move",
                "Move windows from anywhere"
            )
        case .resize:
            return L(
                "shortcuts.gestures.modifier_drag.resize",
                "Resize windows from anywhere"
            )
        }
    }

    /// A row's value as the diff pill reads it: the chord and its
    /// start, or off.
    static func value(_ binding: ModifierDragBinding) -> String {
        guard !binding.isOff else {
            return SettingsValueReadout.onOff(false)
        }
        return L(
            "shortcuts.gestures.modifier_drag.value",
            "%1$@ %2$@",
            ScrollChordGlyphs.text(binding.chord),
            startTitle(binding.start)
        )
    }

    static func startTitle(_ start: ModifierDragStart) -> String {
        switch start {
        case .drag:
            return L("shortcuts.gestures.modifier_drag.start_drag", "+ drag")
        case .hover:
            return L(
                "shortcuts.gestures.modifier_drag.start_hover",
                "+ move (no click)"
            )
        }
    }

    private func row(_ action: ModifierDragAction) -> some View {
        let other: ModifierDragAction = action == .move ? .resize : .move
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Self.title(action))
                .accessibilityHidden(true)
            Spacer(minLength: 8)
            ModifierDragRecorderField(
                name: Self.title(action),
                chord: $model.config.modifierDrag[action].chord,
                other: drags[other].chord,
                otherAction: other
            )
            Picker(
                Self.title(action),
                selection: $model.config.modifierDrag[action].start
            ) {
                ForEach(ModifierDragStart.allCases, id: \.self) { start in
                    Text(Self.startTitle(start)).tag(start)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .neutralMenuLabel()
            .fixedSize()
            .accessibilityLabel(Self.title(action))
            .accessibilityValue(Self.startTitle(drags[action].start))
        }
    }
}
