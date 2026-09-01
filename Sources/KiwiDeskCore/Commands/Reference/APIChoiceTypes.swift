import Foundation

// Census of all enum types accepted by command API arguments
// (#1033), declared centrally so one file answers "what enums
// does the API expose". `CaseIterable` stays at each enum's own
// declaration — Swift synthesizes `allCases` only there.

extension KiwiNotification: APIChoiceType {}

extension Direction: APIChoiceType {}
extension StickyReachOverride: APIChoiceType {}
extension LayoutMode: APIChoiceType {}
extension SpawnPlacement: APIChoiceType {}
extension MouseResizeMode: APIChoiceType {}
extension SizePolicy: APIChoiceType {}
extension QuitLayoutStyle: APIChoiceType {}

extension BspParams.Strategy: APIChoiceType {}
extension ScrollingParams.Anchor: APIChoiceType {}
extension ScrollingParams.Orientation: APIChoiceType {}
extension StackParams.OverflowStyle: APIChoiceType {}
extension StackParams.Orientation: APIChoiceType {}
extension StackParams.StackPosition: APIChoiceType {}
extension GridParams.GridType: APIChoiceType {}
extension GridParams.SplitDirection: APIChoiceType {}
extension MonocleParams.Orientation: APIChoiceType {}
extension MonocleParams.HideStyle: APIChoiceType {}
extension TrackParams.Axis: APIChoiceType {}
extension TrackParams.NewWindowTrack: APIChoiceType {}

// `SpaceBarStyle` spells its vocabulary as typealiases of these,
// so conforming the `AppBarStyle` types covers both bars.
extension AppBarEdge: APIChoiceType {}
extension AppBarStyle.BarAlignment: APIChoiceType {}
extension AppBarStyle.BackgroundStyle: APIChoiceType {}
extension AppBarStyle.BackgroundFit: APIChoiceType {}
extension AppBarStyle.ActiveIndicator: APIChoiceType {}
extension AppBarStyle.Content: APIChoiceType {}
extension BarAppIconSource: APIChoiceType {}

extension BorderStyle.CornerStyle: APIChoiceType {}
extension BorderStyle.DrawOrder: APIChoiceType {}
extension BorderAlignment: APIChoiceType {}
