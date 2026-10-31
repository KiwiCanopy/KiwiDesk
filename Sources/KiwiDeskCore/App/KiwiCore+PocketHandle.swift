import AppKit

/// The pocket's handle on an edge no bar shows (#2678, 2026-10-29
/// ruling): a fixed mark at Position on the screen's edge, out of
/// which the pocket rises on hover and during a window drag, to the
/// size it has on that edge's bar, its mark kept within 20...32 pt.
extension KiwiCore {
    /// The risen pocket's side: a section's on a bar `thickness`
    /// deep, so the mark draws alike (#2776), its mark kept between
    /// `PocketHandleView.markSide` and `pocketRiseMarkCap`.
    static func pocketRiseSide(thickness: CGFloat) -> CGFloat {
        let share = PocketMarkGeometry.markShare
        let mark = min(
            max(thickness * share, PocketHandleView.markSide),
            pocketRiseMarkCap
        )
        return mark / share
    }

    /// The risen mark's largest side.
    static let pocketRiseMarkCap: CGFloat = 32

    /// The handle's frame on `display` (AX), risen or at rest, a
    /// peek deeper while `peeking`.
    func pocketHandleFrame(
        on display: DisplayID,
        risen: Bool,
        peeking: Bool = false
    ) -> CGRect? {
        let shelf = tiler.settings.kiwishelf
        // Reaching the edge across the outer margin, as the bars'
        // hover bands do; the handle draws past it (#2678).
        return pocketHandleFrame(
            on: display,
            depth: shelf.outerMargin
                + (risen
                    ? PocketHandleView.tabDepth + PocketPlateView.lift
                        + Self.pocketRiseSide(thickness: shelf.thickness)
                    : PocketHandleView.restDepth
                        + (peeking ? PocketHandleView.peekDepth : 0))
        )
    }

    /// Whether the whole mark stands at rest on `display`: its edge
    /// shows no bar there and the bars read Always (#2784 ▸ 8).
    func pocketRestsWhole(on display: Display) -> Bool {
        let mode =
            state.workspaces.currentSpace(on: display.id)
            .flatMap { state.workspaces[$0]?.mode } ?? .bsp
        return tiler.settings.pocketRest(in: mode, on: display.fingerprint)
            == .mark
    }

    /// The whole mark's frame on `display` (AX): a square a section
    /// deep, one outer margin in from the edge, centred where the
    /// handle stands (#2784).
    func pocketMarkFrame(on display: DisplayID) -> CGRect? {
        let shelf = tiler.settings.kiwishelf
        let side = shelf.thickness
        guard
            let band = pocketHandleFrame(
                on: display,
                depth: shelf.outerMargin + side
            )
        else { return nil }
        return shelf.pocketEdge.isHorizontal
            ? band.insetBy(dx: (band.width - side) / 2, dy: 0)
            : band.insetBy(dx: 0, dy: (band.height - side) / 2)
    }

    /// The handle's band on `display` (AX), `depth` deep.
    private func pocketHandleFrame(
        on display: DisplayID,
        depth: CGFloat
    ) -> CGRect? {
        guard let screen = TilingEngine.screen(for: display) else {
            return nil
        }
        let shelf = tiler.settings.kiwishelf
        let visible = GeometryUtils.axVisibleFrame(of: screen)
        // Where the shown pocket stands on an Auto edge, else at
        // Position (#2678).
        if let band = pocketPlate.markBands[display] {
            return Self.pocketHandleFrame(
                visible: visible,
                edge: shelf.pocketEdge,
                band: band,
                depth: depth
            )
        }
        return Self.pocketHandleFrame(
            visible: visible,
            edge: shelf.pocketEdge,
            position: shelf.pocketPosition,
            depth: depth
        )
    }

    /// A band `ShelfMarkPlacement.bandLength` long at `position`
    /// percent along `edge` of `visible`, `depth` deep, kept whole
    /// on the edge.
    static func pocketHandleFrame(
        visible: CGRect,
        edge: AppBarEdge,
        position: CGFloat,
        depth: CGFloat
    ) -> CGRect {
        let share = max(0, min(position, 100)) / 100
        let horizontal = edge.isHorizontal
        let low = horizontal ? visible.minX : visible.minY
        let high = horizontal ? visible.maxX : visible.maxY
        let length = ShelfMarkPlacement.bandLength
        let start = min(
            max(low + (high - low) * share - length / 2, low),
            max(high - length, low)
        )
        return pocketHandleFrame(
            visible: visible,
            edge: edge,
            band: start...(start + length),
            depth: depth
        )
    }

    /// The handle `depth` deep on `edge` of `visible`, along `band`
    /// (AX, along the edge) — its band in an Auto edge's row of
    /// marks, taken as the row laid it.
    static func pocketHandleFrame(
        visible: CGRect,
        edge: AppBarEdge,
        band span: ClosedRange<CGFloat>,
        depth: CGFloat
    ) -> CGRect {
        let band = span.upperBound - span.lowerBound
        switch edge {
        case .bottom:
            return CGRect(
                x: span.lowerBound,
                y: visible.maxY - depth,
                width: band,
                height: depth
            )
        case .top:
            return CGRect(
                x: span.lowerBound,
                y: visible.minY,
                width: band,
                height: depth
            )
        case .left:
            return CGRect(
                x: visible.minX,
                y: span.lowerBound,
                width: depth,
                height: band
            )
        case .right:
            return CGRect(
                x: visible.maxX - depth,
                y: span.lowerBound,
                width: depth,
                height: band
            )
        }
    }

    /// Where a put-in or take-out lands on `display` (AX): the
    /// pocket drawn there — its bar section, or the pocket risen out
    /// of its handle — else nil, where none stands (#2678).
    func pocketLanding(on display: DisplayID) -> CGRect? {
        // The one door for where the pocket is (#2678 review 5).
        guard pocketStands(on: display) else { return nil }
        let shelf = tiler.settings.kiwishelf
        switch pocketPlace(on: display) {
        case .section(let frame), .inside(let frame): return frame
        case .whole:
            return pocketMarkFrame(on: display).map {
                PocketPlateView.room(
                    in: $0,
                    edge: shelf.pocketEdge,
                    outer: shelf.outerMargin
                )
            }
        case .handle: break
        }
        guard let room = pocketHandleFrame(on: display, risen: true) else {
            return nil
        }
        let rise = Self.pocketRiseSide(thickness: shelf.thickness)
        // AX coordinates run down, as the view's flipped bounds do.
        return PocketPlateView.risenFrame(
            in: PocketPlateView.room(
                in: room,
                edge: shelf.pocketEdge,
                outer: shelf.outerMargin
            ),
            edge: shelf.pocketEdge,
            side: rise
        )
    }

    /// Holds `display`'s pocket out of its handle for a play
    /// `seconds` long, so the window lands on a pocket the screen
    /// shows. The latest play wins on every display: a play on
    /// another screen ends this one's hold, its pocket sinking once
    /// that play's landing has passed.
    func holdPocketOut(on display: DisplayID, for seconds: TimeInterval) {
        let token = UUID()
        pocketPlate.playing = [display: token]
        // A play stands the pocket, its place the bar pass's.
        updateBars()
        deferred.schedule(.pocketHold, after: .seconds(seconds)) {
            [weak self] in
            guard let self, self.pocketPlate.playing[display] == token
            else { return }
            self.pocketPlate.playing[display] = nil
            self.updateBars()
        }
    }

    /// The pointer came onto `display`'s handle or left it. On it,
    /// the pocket rises after the bars' reveal delay (#2807).
    func pocketHovered(_ display: DisplayID, _ on: Bool) {
        let was = pocketPlate.hovered.contains(display)
        guard was != on else { return }
        if on {
            pocketPlate.hovered.insert(display)
            deferred.schedule(
                .pocketDwell,
                after: .seconds(ShelfReveal.revealDelay)
            ) { [weak self] in
                guard let self, self.pocketPlate.hovered.contains(display)
                else { return }
                self.pocketPlate.dwelled.insert(display)
                self.updatePocketPlate()
            }
        } else {
            pocketPlate.hovered.remove(display)
            pocketPlate.dwelled.remove(display)
        }
        updatePocketPlate()
    }

    /// The pointer pushed against the edge on `display`'s handle: the
    /// pocket rises at once, as a push opens a bar.
    func pocketPushed(_ display: DisplayID) {
        guard pocketPlate.hovered.contains(display),
            pocketPlate.dwelled.insert(display).inserted
        else { return }
        updatePocketPlate()
    }
}
