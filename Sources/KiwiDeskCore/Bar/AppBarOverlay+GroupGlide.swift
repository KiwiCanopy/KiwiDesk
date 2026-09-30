import AppKit

/// A group's members slide together into its item as it collapses
/// and out of it as it expands (#1831), rather than the row
/// swapping content in place. Item views are keyed by the window
/// they stand for, so a view that stays glides to its new slot, a
/// member absorbed into a group slides onto the group's slot and
/// fades, and a member released from one starts on that slot.
extension AppBarOverlay {
    /// A view leaving the run into the item that absorbed it.
    struct Departure {
        let view: AppBarItemView
        let into: WindowID
    }

    /// A new view and the frame of the item it was folded into.
    struct Arrival {
        let view: AppBarItemView
        let from: CGRect
    }

    /// Reuses each view whose window still has an item, in the
    /// items' order; returns the views folded into another item and
    /// the new ones released from one. A view whose window left the
    /// bar goes at once. Per-item glass keeps its views by POSITION
    /// — a view moves between glasses only on a host change
    /// (bars.md, #1315) — so a boxed glass run snaps as before.
    func syncItemViews(
        to items: [Item]
    ) -> (departures: [Departure], arrivals: [Arrival]) {
        let old = itemViews
        guard old.allSatisfy({ $0.superview === itemRun }) else {
            syncItemViewCount(items.count)
            return ([], [])
        }
        var byID = Dictionary(
            old.map { ($0.windowID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var next: [AppBarItemView] = []
        var arrivals: [Arrival] = []
        for item in items {
            if let view = byID.removeValue(forKey: item.id) {
                next.append(view)
                continue
            }
            let view = AppBarItemView()
            itemRun.addSubview(view)
            next.append(view)
            if let source = old.first(where: {
                $0.members.contains(item.id) && $0.superview === itemRun
            }), source.frame != .zero {
                arrivals.append(Arrival(view: view, from: source.frame))
            }
        }
        var departures: [Departure] = []
        for view in byID.values {
            if view.superview === itemRun,
                let target = items.first(where: {
                    $0.members.contains(view.windowID)
                })
            {
                departures.append(Departure(view: view, into: target.id))
            } else {
                view.removeFromSuperview()
            }
        }
        itemViews = next
        return (departures, arrivals)
    }

    /// Plays the glide inside the render's layout group: arrivals
    /// fade in from their group's slot, departures slide onto the
    /// item that absorbed them and fade out, then leave.
    func playGroupGlide(
        departures: [Departure],
        arrivals: [Arrival],
        items: [Item],
        frames: [CGRect]
    ) {
        for arrival in arrivals {
            BarMotion.setAlpha(arrival.view, to: 1, animated: true)
        }
        for departure in departures {
            guard
                let index = items.firstIndex(where: {
                    $0.id == departure.into
                }), frames.indices.contains(index)
            else { continue }
            BarMotion.setFrame(
                departure.view,
                to: frames[index],
                animated: true
            )
            BarMotion.setAlpha(departure.view, to: 0, animated: true)
        }
    }

    /// Stands each arrival on its group's slot, transparent, ahead
    /// of the frame pass that moves it out.
    func standArrivals(_ arrivals: [Arrival]) {
        for view in itemViews { view.alphaValue = 1 }
        for arrival in arrivals {
            arrival.view.frame = arrival.from
            arrival.view.alphaValue = 0
        }
    }

    /// Positional reuse, for a run whose views a glass hosts.
    private func syncItemViewCount(_ count: Int) {
        while itemViews.count > count {
            itemViews.removeLast().removeFromSuperview()
        }
        while itemViews.count < count {
            let view = AppBarItemView()
            itemViews.append(view)
            itemRun.addSubview(view)
        }
    }
}
