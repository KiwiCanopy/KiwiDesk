import KiwiDeskCore
import SwiftUI

/// A `GestureItem`'s picture as a view of its own, so an entry
/// built from an item can name its picture's type.
struct GestureItemPicture: View {
    let item: GestureItem
    let t: CGFloat
    let gestures: ScrollGestureBase

    var body: some View {
        item.picture(t: t, gestures: gestures)
    }
}

extension GestureEntry where Picture == GestureItemPicture {
    /// The entry for `item`: its sentence, picture and
    /// pace, greyed where `item.isOff` says. It plays once as it
    /// appears while `playing` names it, and spends that.
    init(
        _ item: GestureItem,
        settings: TilingSettings,
        gestures: ScrollGestureBase,
        help: String? = nil,
        helpSubject: String? = nil,
        playing: Binding<GestureItem?>,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.init(
            item.sentence(settings),
            pace: item.pace,
            off: item.isOff(gestures),
            help: help,
            helpSubject: helpSubject,
            playsOnAppear: Binding(
                get: { playing.wrappedValue == item },
                set: {
                    if !$0, playing.wrappedValue == item {
                        playing.wrappedValue = nil
                    }
                }
            ),
            picture: {
                GestureItemPicture(item: item, t: $0, gestures: gestures)
            },
            control: control
        )
    }
}

extension GestureEntry
where Picture == GestureItemPicture, Control == EmptyView {
    init(
        _ item: GestureItem,
        settings: TilingSettings,
        gestures: ScrollGestureBase,
        playing: Binding<GestureItem?>
    ) {
        self.init(
            item,
            settings: settings,
            gestures: gestures,
            playing: playing
        ) { EmptyView() }
    }
}
