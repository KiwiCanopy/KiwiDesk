import KiwiDeskCore
import SwiftUI

/// The desk inside a look's picture (#1740): three whole windows
/// at the look's gaps through the one gap remap, the centre one
/// focused. The side windows are paper the ground shows through,
/// ringed only while the draft draws unfocused rings.
struct LookDesk: View {
    let plate: LookPlate

    private var settings: TilingSettings { plate.settings }

    var body: some View {
        let gaps = settings.gapsGlobal
        let inner = gap(gaps.inner.horizontal)
        GeometryReader { well in
            let room = max(0, well.size.width - inner * 2)
            HStack(spacing: inner) {
                side.frame(width: room * Self.sideShare)
                focused
                side.frame(width: room * Self.sideShare)
            }
        }
        .padding(.horizontal, gap(gaps.outer.left))
        .padding(.top, gap(gaps.outer.top))
        .padding(.bottom, gap(gaps.outer.bottom))
        .padding(reserve.edges, reserve.depth)
    }

    /// The strip a lone pocket keeps clear on its edge.
    private var reserve: (edges: Edge.Set, depth: CGFloat) {
        let depth = LookPlate.lonePocketSide
        switch plate.pocketReserve {
        case .top: return (.top, depth)
        case .bottom: return (.bottom, depth)
        case .left: return (.leading, depth)
        case .right: return (.trailing, depth)
        case nil: return ([], 0)
        }
    }

    /// Each side window's share of the row, the focused one the
    /// rest.
    private static let sideShare: CGFloat = 0.22

    /// A gap on the picture: the gaps diagram's remap at the
    /// plate's size.
    private func gap(_ real: CGFloat) -> CGFloat {
        GapPreviewScale.mini(real) * Self.gapShare
    }

    /// The gaps diagram's mini screen against this plate.
    private static let gapShare: CGFloat = 0.3

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: settings.borderStyle.cornerStyle == .square
                ? 0 : 3
        )
    }

    private var focused: some View {
        ZStack {
            plate.focusGlow(shape)
            shape.fill(SettingsTheme.lookWindow)
            lines
            plate.focusRing(shape)
        }
    }

    private var side: some View {
        shape.fill(SettingsTheme.lookWindow.opacity(0.4))
            .overlay {
                if settings.borderStyle.unfocusedEnabled {
                    shape.strokeBorder(
                        Color(kiwiHex: settings.borderStyle.unfocusedColor),
                        lineWidth: max(1, plate.ringWidth * 0.5)
                    )
                }
            }
    }

    /// A window's placeholder lines: a title line and three of
    /// text, which no look sets (owner, 2026-10-30).
    private var lines: some View {
        GeometryReader { window in
            let unit = window.size.height / 12
            VStack(alignment: .leading, spacing: unit * 0.7) {
                line(unit, share: 1).padding(.bottom, unit * 0.5)
                line(unit, share: 1)
                line(unit, share: 0.55)
                line(unit, share: 0.55)
            }
            .padding(unit * 1.4)
            .frame(width: window.size.width, alignment: .leading)
        }
    }

    private func line(_ unit: CGFloat, share: CGFloat) -> some View {
        Capsule()
            .fill(SettingsTheme.lookWindowLine)
            .frame(height: unit * 0.8)
            .scaleEffect(x: share, anchor: .leading)
    }
}

/// The App Bar's apps on a look's picture (#1740): Finder, Safari
/// and Mail in the Dock's order, each its own icon, or its App Font
/// ligature for a look drawing symbols.
extension LookPlate {
    static let apps: [(bundleID: String, ligature: String)] = [
        ("com.apple.finder", ":finder:"),
        ("com.apple.Safari", ":safari:"),
        ("com.apple.mail", ":mail:"),
    ]

    @MainActor static func appArt(
        _ source: BarAppIconSource
    ) -> [HomeCardBarsTile.BarArt] {
        apps.map { app in
            source == .appFont && AppFont.font(size: 12) != nil
                ? .appFont(app.ligature)
                : .icon(AppIconCache.shared.icon(forBundleID: app.bundleID))
        }
    }
}
