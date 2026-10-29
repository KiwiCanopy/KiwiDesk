import SwiftUI

/// Why the shell's content last changed (#2737 ruling 13), so each
/// change plays its own motion: the root switch converges, a Home
/// card expands into its page and back, and a landing with no card
/// behind it zooms through. Recorded on `nav` beside the change.
enum ShellMotion: Equatable {
    case none
    /// The `Simple | Advanced` switch.
    case converge
    /// A Home card opening its page, and Back to it.
    case expand(SettingsDestination)
    /// A search hit, a link or a landing from outside the window.
    case zoomThrough

    /// The shell's spring; every reader gates it at its call.
    static let spring = Animation.spring(response: 0.7, dampingFraction: 0.86)
    /// Simple fades out before Home's cards arrive.
    static let simpleFade: Double = 0.16
    /// Each card's lag behind the one before it, by grid index.
    static let stagger: Double = 0.025
    /// A page's content fades in once its box has grown.
    static let contentLag: Double = 0.25

    /// The matched box a card and its page share.
    static func boxID(_ destination: SettingsDestination) -> String {
        "box." + destination.rawValue
    }

    /// The matched title a card and the header share.
    static func titleID(_ destination: SettingsDestination) -> String {
        "title." + destination.rawValue
    }

    /// Which branch the shell shows, the one value its animation
    /// keys on — a page-to-page jump keeps the branch and springs
    /// nothing.
    enum Branch: Equatable {
        case simple, home, page
    }
}

private struct ShellSpaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// The shell's namespace, where a card and its page share a box.
    var shellSpace: Namespace.ID? {
        get { self[ShellSpaceKey.self] }
        set { self[ShellSpaceKey.self] = newValue }
    }
}

extension View {
    /// Joins `id`'s matched box in the shell's namespace, where one
    /// is set.
    @ViewBuilder
    func shellMatched(_ id: String, in space: Namespace.ID?) -> some View {
        if let space {
            matchedGeometryEffect(id: id, in: space)
        } else {
            self
        }
    }
}

/// A view leaving behind the page that grew over it: dimmed and
/// blurred (#2737 ruling 13).
struct ShellRecede: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 6 : 0)
            .opacity(active ? 0 : 1)
    }
}

/// A Home card arriving from the window's centre under the switch
/// (#2737 ruling 13): staggered by grid index, after Simple's fade.
struct HomeConverge: ViewModifier {
    let arrived: Bool
    let index: Int
    let viewport: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let away = !(arrived || reduceMotion)
        let centre = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        return
            content
            .visualEffect { effect, proxy in
                let frame = proxy.frame(in: .named(HomeConverge.space))
                return
                    effect
                    .offset(
                        x: away ? centre.x - frame.midX : 0,
                        y: away ? centre.y - frame.midY : 0
                    )
                    .scaleEffect(away ? 0.6 : 1)
                    .opacity(away ? 0 : 1)
            }
            .animation(
                reduceMotion
                    ? nil
                    : ShellMotion.spring.delay(
                        ShellMotion.simpleFade
                            + Double(index) * ShellMotion.stagger
                    ),
                value: arrived
            )
    }

    /// The viewport the cards fly from the centre of.
    static let space = "homeViewport"
}

/// A page's content arriving after its box has grown out of the
/// card (#2737 ruling 13): the box stays opaque, only what is on it
/// fades in late.
struct PageContentLag: ViewModifier {
    let lags: Bool
    @State private var shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(lags: Bool) {
        self.lags = lags
        _shown = State(initialValue: !lags)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.2).delay(ShellMotion.contentLag),
                value: shown
            )
            .onAppear { shown = true }
    }
}
