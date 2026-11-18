import CoreGraphics

extension TilingSettings {
    /// Whether some handle rests on screen, in some layout on some
    /// screen — what Settings' Handle thickness row asks to grey
    /// (#3451): a bar resting as its handle on its edge, asked of
    /// the one `ShelfEdge.handled(hover:)` with the bars a maximized
    /// window brings in (`maximizedHoverBars`), or the Pocket resting
    /// as its handle in a layout it rests in (`pocketRests(in:)`).
    /// A stored Hidden bar rests as nothing, so it counts for none.
    public var someHandleRests: Bool {
        let bar = screenVariants.contains { screen in
            LayoutMode.allCases.contains { mode in
                let hover = screen.maximizedHoverBars(in: mode)
                return screen.barEdges(in: mode).contains {
                    !$0.handled(hover: hover).isEmpty
                }
            }
        }
        let screens: [String?] = [nil] + edgeScreens.map(Optional.some)
        let pocket = screens.contains { screen in
            LayoutMode.allCases.contains {
                pocketRests(in: $0)
                    && pocketRest(in: $0, on: screen) == .handle
            }
        }
        return bar || pocket
    }
}
