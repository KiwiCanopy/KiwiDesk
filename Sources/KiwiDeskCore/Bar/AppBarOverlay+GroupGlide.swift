import AppKit

/// A group's members slide together into its item as it collapses
/// and out of it as it expands (#1831), rather than the row
/// swapping content in place. Item views, their box glass and the
/// members still gliding are all keyed by the window they stand
/// for, so a view that stays glides to its new slot, a member
/// absorbed into a group slides onto the group's slot and fades,
/// and a member released from one starts on that slot. On a boxed
/// glass run only the CONTENT travels: no glass glides into another.
/// A Space switch DISSOLVES instead (#1838): the old row's content
/// fades out where it stands, bare, cropped by the section as it
/// resizes, while the new row's fades in at its slots. The boxes
/// cut: a glass takes no alpha — at partial opacity it shows the
/// tint behind it bare — and no geometry — its content re-lays
/// every frame (device, 2026-10-01).
extension AppBarOverlay {
    /// A view leaving the run: into the item that absorbed it, or
    /// — `into` nil — fading out where it stands on a dissolve.
    struct Departure {
        let view: AppBarItemView
        let into: WindowID?
    }

    /// A new view, its window, and the frame of the item it was
    /// folded into — `.zero` for one fading in at its own slot on
    /// a dissolve.
    struct Arrival {
        let view: AppBarItemView
        let id: WindowID
        let from: CGRect
    }

    /// Reuses each view whose window still has an item, in the
    /// items' order, its glass paired by window where `glass`;
    /// returns the views folded into another item and the new ones
    /// released from one. A view whose window left the bar goes at
    /// once — or, `dissolving`, fades out where it stands while
    /// every new view fades in at its slot.
    func syncItemViews(
        to items: [Item],
        glass: Bool,
        dissolving: Bool = false
    ) -> (departures: [Departure], arrivals: [Arrival]) {
        let old = itemViews
        var hosts = boxGlassHosts()
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
                let from = hosts[source.windowID]?.glass.frame ?? source.frame
                if from != .zero {
                    arrivals.append(
                        Arrival(view: view, id: item.id, from: from)
                    )
                }
            } else if dissolving {
                arrivals.append(Arrival(view: view, id: item.id, from: .zero))
            }
        }
        var departures: [Departure] = []
        for view in byID.values {
            let host = hosts.removeValue(forKey: view.windowID)
            if let target = items.first(where: {
                $0.members.contains(view.windowID)
            }) {
                if let host { unhost(view, from: host.glass, tint: host.tint) }
                departures.append(Departure(view: view, into: target.id))
            } else if dissolving {
                if let host { unhost(view, from: host.glass, tint: host.tint) }
                departures.append(Departure(view: view, into: nil))
            } else {
                Self.discard(view, glass: host?.glass, tint: host?.tint)
            }
        }
        itemViews = next
        if glass { pairBoxGlasses(with: items.map(\.id), hosts: hosts) }
        // A dissolve arrival slides under no glass, so it takes its
        // own at once and fades in inside it.
        glidingIn.formUnion(arrivals.filter { $0.from != .zero }.map(\.id))
        return (departures, arrivals)
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

    /// Plays the glide inside the render's layout group: arrivals
    /// fade in from their group's slot — a dissolve's at its own —
    /// departures slide onto the item that absorbed them and fade
    /// out, a dissolve's fading where it stands, early, on the
    /// out-fade group. Both rows fade from the first frame:
    /// holding the new row back left the boxes empty between
    /// (owner, device 2026-10-01).
    func playGroupGlide(
        departures: [Departure],
        arrivals: [Arrival],
        items: [Item],
        frames: [CGRect]
    ) {
        for arrival in arrivals {
            BarMotion.setAlpha(arrival.view, to: 1, animated: true)
        }
        BarMotion.runDissolveOut {
            for departure in departures where departure.into == nil {
                BarMotion.setAlpha(departure.view, to: 0, animated: true)
            }
        }
        for departure in departures {
            guard let into = departure.into else { continue }
            guard
                let index = items.firstIndex(where: { $0.id == into }),
                frames.indices.contains(index)
            else { continue }
            BarMotion.setFrame(
                departure.view,
                to: frames[index],
                animated: true
            )
            BarMotion.setAlpha(departure.view, to: 0, animated: true)
        }
        guard !departures.isEmpty || !arrivals.isEmpty else { return }
        glideGeneration += 1
        let generation = glideGeneration
        let landed = Set(arrivals.map(\.id))
        BarMotion.afterGroupGlide { [weak self] in
            self?.landGroupGlide(
                departures: departures,
                landed: landed,
                generation: generation
            )
        }
    }

    /// A glide landing: its departures leave, its arrivals stop
    /// gliding, and — for the latest glide only, which a newer one
    /// supersedes — a boxed glass run re-renders so they take their
    /// glass: a host change, so the reparent is this arm's (#1315).
    func landGroupGlide(
        departures: [Departure],
        landed: Set<WindowID>,
        generation: Int
    ) {
        for departure in departures {
            departure.view.removeFromSuperview()
        }
        glidingIn.subtract(landed)
        guard generation == glideGeneration, !landed.isEmpty,
            !boxGlasses.isEmpty, lastShown != nil
        else { return }
        render(followingFocus: false)
    }

    /// Stands each arrival on its group's slot, transparent, ahead
    /// of the frame pass that moves it out — a dissolve's stays at
    /// its own slot; a view still gliding in from an earlier render
    /// keeps its fade.
    func standArrivals(_ arrivals: [Arrival]) {
        for view in itemViews where !glidingIn.contains(view.windowID) {
            view.alphaValue = 1
        }
        for arrival in arrivals {
            if arrival.from != .zero { arrival.view.frame = arrival.from }
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
