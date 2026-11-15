import Foundation

/// The Space a window's app rules name (#3341): a titled rule
/// matching its title beats the app's bare rule, and a window
/// whose title arrives late may be filed by one once.
extension StateCoordinator {
    /// The Space the app rules file `window` in, read at its
    /// creation: the first titled rule its title matches, else the
    /// bare rule; nil where neither names one.
    func appRuleSpace(of window: ManagedWindow) -> SpaceID? {
        titledAppRules.pick(
            app: window.appRef.listKey,
            title: window.title,
            bare: appRules
        )?.space
    }

    /// Records `window`, which arrived at `stamp`, for one late
    /// titled match. Only a window the rule gate was open for
    /// (`ruleGateOpen`) and whose app holds a titled rule its title
    /// did not match is recorded; one a rule already followed into
    /// its Space is not, or a second move would land a beat after
    /// the follow.
    mutating func noteTitledRulePending(
        _ window: ManagedWindow,
        arrivedAt stamp: Date?,
        ruleGateOpen: Bool,
        followed: Bool
    ) {
        titledRulePending[window.id] = nil
        guard ruleGateOpen, !followed, let stamp,
            let app = window.appRef.listKey,
            titledAppRules.hasRule(app: app),
            titledAppRules.rule(app: app, title: window.title) == nil
        else { return }
        titledRulePending[window.id] = stamp
    }

    /// The late match a title report owes, consuming the record: the
    /// first titled rule the new title matches. A report that
    /// matches nothing, or a rule whose Space is gone, leaves the
    /// record for the next one.
    mutating func consumeTitledRule(
        _ id: WindowID,
        title: String
    ) -> AppliedEffects.LateTitledRule? {
        guard let arrived = titledRulePending[id],
            let app = windows[id]?.appRef.listKey,
            let space = titledAppRules.space(app: app, title: title),
            workspaces[space] != nil
        else { return nil }
        titledRulePending[id] = nil
        return .init(window: id, space: space, arrivedAt: arrived)
    }
}
