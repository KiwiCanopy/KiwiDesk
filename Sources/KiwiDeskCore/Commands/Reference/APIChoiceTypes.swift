import Foundation

// The census of every enum an API argument can take (#1033).
//
// A conformance here is what lets `APIArgument.choice` read a
// decoder's cases instead of a record re-typing them. The list
// is the whole vocabulary the Lua/CLI surface accepts, so the
// conformance is declared once, centrally, rather than beside
// each enum: a reader asking "what enums does the API expose?"
// has one file to read, and phase 2 of #1033 writes records
// without touching the derivation.
//
// `CaseIterable` itself is declared at each enum's own
// declaration — Swift synthesizes `allCases` only there.

// MARK: - Events

extension KiwiNotification: APIChoiceType {}

// MARK: - Navigation & modes

extension Direction: APIChoiceType {}
extension LayoutMode: APIChoiceType {}
extension SpawnPlacement: APIChoiceType {}
extension MouseResizeMode: APIChoiceType {}
extension QuitLayoutStyle: APIChoiceType {}

// MARK: - Layout parameters

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

// MARK: - Bars

// `SpaceBarStyle` spells its own vocabulary as typealiases of
// these, so conforming the `AppBarStyle` types covers both bars.
extension AppBarEdge: APIChoiceType {}
extension AppBarStyle.BarAlignment: APIChoiceType {}
extension AppBarStyle.BackgroundStyle: APIChoiceType {}
extension AppBarStyle.BackgroundFit: APIChoiceType {}
extension AppBarStyle.ActiveIndicator: APIChoiceType {}
extension AppBarStyle.Content: APIChoiceType {}
extension BarAppIconSource: APIChoiceType {}

// MARK: - Borders & drag visuals

extension BorderStyle.CornerStyle: APIChoiceType {}
extension BorderStyle.DrawOrder: APIChoiceType {}
extension BorderAlignment: APIChoiceType {}
