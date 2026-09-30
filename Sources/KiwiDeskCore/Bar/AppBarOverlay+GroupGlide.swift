import AppKit

/// A group's members slide together into its item as it collapses
/// and out of it as it expands (#1831), rather than the row
/// swapping content in place. Item views are keyed by the window
/// they stand for — and a boxed glass run's glass and tint by the
/// view they host, so no view changes glass (bars.md, #1315) — so
/// a view that stays glides to its new slot, a member absorbed
/// into a group slides onto the group's slot and fades, and a
/// member released from one starts on that slot.
///
/// On a boxed glass run only the CONTENT travels: a departing
/// member leaves its glass at once, and an arriving one takes its
/// glass when it lands (`glidingIn`). A glass sliding under
/// another ghosts through it and re-samples its backdrop every
/// frame (owner, device 2026-09-30), so no box ever glides into one.
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
    /// items' order, its glass and tint moving with it; returns the
    /// views folded into another item and the new ones released
    /// from one. A view whose window left the bar goes at once.
    func syncItemViews(
        to items: [Item]
    ) -> (departures: [Departure], arrivals: [Arrival]) {
        let old = itemViews
        var hosts = glassHosts(of: old)
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
            if let source = old.first(where: { $0.members.contains(item.id) }
            ) {
                let from =
                    hosts[ObjectIdentifier(source)]?.glass.frame
                    ?? source.frame
                if from != .zero {
                    arrivals.append(Arrival(view: view, from: from))
                }
            }
        }
        var departures: [Departure] = []
        for view in byID.values {
            let host = hosts.removeValue(forKey: ObjectIdentifier(view))
            guard
                let target = items.first(where: {
                    $0.members.contains(view.windowID)
                })
            else {
                Self.discard(view, glass: host?.glass, tint: host?.tint)
                continue
            }
            if let host { unhost(view, from: host.glass, tint: host.tint) }
            departures.append(Departure(view: view, into: target.id))
        }
        itemViews = next
        pairGlasses(with: next, hosts: hosts)
        glidingIn.formUnion(arrivals.map { ObjectIdentifier($0.view) })
        return (departures, arrivals)
    }

    /// Each glass and tint by the view it hosts.
    private func glassHosts(
        of views: [AppBarItemView]
    ) -> [ObjectIdentifier: (glass: NSView, tint: GlassBackdrop)] {
        var hosts: [ObjectIdentifier: (NSView, GlassBackdrop)] = [:]
        for (index, glass) in boxGlasses.enumerated()
        where index < views.count && index < boxTints.count
            && GlassPlate.holds(glass, views[index])
        {
            hosts[ObjectIdentifier(views[index])] = (glass, boxTints[index])
        }
        return hosts.mapValues { (glass: $0.0, tint: $0.1) }
    }

    /// Takes a departing view out of its glass where the glass
    /// stood, through `GlassPlate.release` (#1730), and drops the
    /// glass and tint at once.
    private func unhost(
        _ view: AppBarItemView,
        from glass: NSView,
        tint: GlassBackdrop
    ) {
        let frame = glass.frame
        GlassPlate.release(glass)
        itemRun.addSubview(view)
        view.frame = frame
        glass.removeFromSuperview()
        tint.removeFromSuperview()
    }

    /// Re-orders the glass pool to follow `views`; a view with no
    /// glass yet takes a fresh one at its place, and a pool that
    /// cannot mint one is left for `updateBoxGlasses` to refill.
    private func pairGlasses(
        with views: [AppBarItemView],
        hosts: [ObjectIdentifier: (glass: NSView, tint: GlassBackdrop)]
    ) {
        guard !boxGlasses.isEmpty else { return }
        var glasses: [NSView] = []
        var tints: [GlassBackdrop] = []
        for view in views {
            if let host = hosts[ObjectIdentifier(view)] {
                glasses.append(host.glass)
                tints.append(host.tint)
            } else if let glass = GlassPlate.make() {
                itemRun.addSubview(glass)
                glasses.append(glass)
                tints.append(GlassBackdrop())
            } else {
                break
            }
        }
        boxGlasses = glasses
        boxTints = tints
    }

    /// Plays the glide inside the render's layout group: arrivals
    /// fade in from their group's slot, departures slide onto the
    /// item that absorbed them and fade out; once it lands the
    /// departures leave and the arrivals take their glass.
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
        guard !departures.isEmpty || !arrivals.isEmpty else { return }
        let landed = Set(arrivals.map { ObjectIdentifier($0.view) })
        BarMotion.afterGroupGlide { [weak self] in
            for departure in departures {
                departure.view.removeFromSuperview()
            }
            guard let self, !landed.isEmpty else { return }
            self.glidingIn.subtract(landed)
            // Hosts the landed members in their glass: a host
            // change, so the reparent is this arm's (#1315).
            if self.boxGlasses.isEmpty == false {
                self.render(followingFocus: false)
            }
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

    /// Takes a view out for good, through `GlassPlate.release` where
    /// a glass hosts it (#1730).
    private static func discard(
        _ view: AppBarItemView,
        glass: NSView?,
        tint: GlassBackdrop?
    ) {
        if let glass {
            GlassPlate.release(glass)
            glass.removeFromSuperview()
        }
        tint?.removeFromSuperview()
        view.removeFromSuperview()
    }
}
