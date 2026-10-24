import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// What the switch cues' plate shows (#2142, #2144).
@MainActor
final class CuePlateModel: ObservableObject {
    /// One plate, two cues.
    enum Content: Equatable {
        case desktop(DesktopSwitchCue)
        case mode(ModeCycleCue)
        case space(SpaceSwitchCue)
    }

    @Published private(set) var content: Content?
    @Published var visible = false
    /// The plate's glass, read at each show (#2569).
    @Published var glass = PanelGlass.untinted

    static let hold: TimeInterval = 0.6
    static let fade: TimeInterval = 0.25
    static let side: CGFloat = 128
    static let tallSide: CGFloat = 152
    static let corner: CGFloat = 28
    static let captionWidth: CGFloat = 208
    /// The panel's fixed room: the widest plate a caption makes,
    /// centred, so a cue never resizes the panel.
    static let room = CGSize(width: captionWidth + 32, height: tallSide)
    static let captionFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    /// The large number both plates draw — a Desktop's, and a
    /// Space's short identifier (#2142, #2143).
    static let digitFont = Font.system(
        size: 64,
        weight: .semibold,
        design: .rounded
    )
    /// The layout step (#2144): one critically damped spring, no
    /// overshoot.
    static let step = Animation.spring(duration: 0.3, bounce: 0)

    /// Shows `content`. A layout cue replacing a layout cue still
    /// up is the step, which moves; every first appearance is
    /// instant (#2142), and Reduce Motion jumps.
    func present(_ content: Content, reduceMotion: Bool) {
        if Self.steps(from: self.content, visible: visible, to: content) {
            withAnimation(reduceMotion ? nil : Self.step) {
                self.content = content
            }
        } else {
            self.content = content
        }
        visible = true
    }

    /// Whether showing `next` over `shown` is the step: a layout
    /// cue replacing one still up. Anything else appears at once.
    static func steps(
        from shown: Content?,
        visible: Bool,
        to next: Content
    ) -> Bool {
        guard visible, case .mode? = shown, case .mode = next else {
            return false
        }
        return true
    }

    /// The caption's own width, capped: a bare `maxWidth` frame
    /// would stretch the plate to the cap for any name.
    static func captionFit(
        _ text: String,
        font: NSFont = captionFont
    ) -> CGFloat {
        let width = (text as NSString)
            .size(withAttributes: [.font: font]).width
        return min(ceil(width) + 1, captionWidth)
    }

    /// The one sentence VoiceOver hears for `content`.
    static func spoken(_ content: Content) -> String {
        switch content {
        case .desktop(let cue): return spoken(cue)
        case .space(let cue):
            return L(
                "space_cue.ax",
                "Space %1$@, %2$@",
                cue.space.raw,
                cue.mode.displayName
            )
        case .mode(let cue):
            return L("mode_cue.ax", "Layout: %1$@", cue.current.displayName)
        }
    }

    /// The spoken cue: "Desktop 2 of 4", "Desktop 4, 2 of 3" where
    /// the screen's own count starts past 1, and the profile a
    /// binding loaded after it.
    static func spoken(_ cue: DesktopSwitchCue) -> String {
        let desktop =
            cue.number == cue.position
            ? L(
                "desktop_cue.ax.same",
                "Desktop %1$d of %2$d",
                cue.number,
                cue.count
            )
            : L(
                "desktop_cue.ax",
                "Desktop %1$d, %2$d of %3$d",
                cue.number,
                cue.position,
                cue.count
            )
        guard let profile = cue.loadedProfile else { return desktop }
        return L(
            "desktop_cue.ax.profile",
            "%1$@, profile %2$@",
            desktop,
            profile
        )
    }
}

/// The plate's room: whichever cue is up, appearing at once and
/// fading on the leave.
struct CuePlateView: View {
    @ObservedObject var model: CuePlateModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        plate
            .frame(
                width: CuePlateModel.room.width,
                height: CuePlateModel.room.height
            )
            .opacity(model.visible ? 1 : 0)
            .animation(
                // Appears at once; only the leave fades (#2142).
                reduceMotion || model.visible
                    ? nil : .easeOut(duration: CuePlateModel.fade),
                value: model.visible
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var plate: some View {
        switch model.content {
        case .desktop(let cue)?: DesktopCueView(cue: cue, glass: model.glass)
        case .mode(let cue)?: ModeCueView(cue: cue, glass: model.glass)
        case .space(let cue)?: SpaceCueView(cue: cue, glass: model.glass)
        case nil: EmptyView()
        }
    }
}
