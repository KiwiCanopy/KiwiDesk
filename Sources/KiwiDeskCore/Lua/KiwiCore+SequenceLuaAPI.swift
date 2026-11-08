import Foundation

/// `KiwiDesk.define_sequence(leader, keys, opts)` (#1871), shaped
/// like `define_layer`: `keys` maps each step key to a function, a
/// `{ fn = …, desc = … }` end key, or `{ name = …, keys = { … } }`
/// opening the next step; `opts` takes the leader's `name` and the
/// `layer` it belongs to, `default` where absent.
extension KiwiCore {
    func registerSequenceAPI(on lua: LuaInterpreter) {
        lua.register("define_sequence") { [weak self, weak lua] args in
            guard let self, let lua else { return .none }
            guard let text = args.first?.stringValue,
                let leader = KeyCombo.parse(text),
                KeySequence.admitsLeader(leader),
                case .table(let table) = args.dropFirst().first ?? .none
            else {
                self.onLog("define_sequence(): expected leader and table")
                Self.releaseRefs(in: args, lua: lua)
                return .none
            }
            var options: [String: LuaValue] = [:]
            if case .table(let opts)? = args.dropFirst(2).first {
                options = opts
            }
            let steps = self.sequenceKeys(
                table,
                under: text,
                leader: leader,
                lua: lua
            )
            var source = KeyBinding.sequence(
                combo: text,
                label: options["name"]?.stringValue ?? ""
            )
            source.meta = KeyBindingMeta(options: options)
            let sequence = KeySequence(
                leader: leader,
                source: source,
                steps: steps
            )
            self.keys.defineSequence(
                sequence,
                in: options["layer"]?.stringValue
                    ?? KeybindingManager.defaultLayer
            )
            return .none
        }
    }

    /// One step's keys, in key order, so a script's sequence reads
    /// back the same every load.
    private func sequenceKeys(
        _ table: [String: LuaValue],
        under path: String,
        leader: KeyCombo,
        lua: LuaInterpreter
    ) -> [KeySequence.Key] {
        var keys: [KeySequence.Key] = []
        for (key, value) in table.sorted(by: { $0.key < $1.key }) {
            guard let combo = KeyCombo.parse(key),
                KeySequence.admitsStep(combo, under: leader),
                let action = sequenceAction(
                    value,
                    under: path + " " + key,
                    leader: leader,
                    lua: lua
                )
            else {
                onLog("define_sequence('\(path)'): bad key '\(key)'")
                Self.releaseRefs(in: [value], lua: lua)
                continue
            }
            var source = KeyBinding(combo: key, label: action.label)
            if case .opens = action.action {
                source = .sequence(combo: key, label: action.label)
            }
            source.meta = action.meta
            // Two spellings of one chord: the last wins, as in a build.
            for lost in keys where lost.combo == combo {
                onLog("define_sequence('\(path)'): '\(lost.stored)' replaced")
                KeySequence.refs(in: [lost]).forEach { lua.release(ref: $0) }
            }
            keys.removeAll { $0.combo == combo }
            keys.append(
                KeySequence.Key(
                    combo: combo,
                    source: source,
                    action: action.action
                )
            )
        }
        return keys
    }

    private func sequenceAction(
        _ value: LuaValue,
        under path: String,
        leader: KeyCombo,
        lua: LuaInterpreter
    ) -> (action: KeySequence.Action, label: String, meta: KeyBindingMeta)? {
        switch value {
        case .functionRef(let ref):
            return (.run(ref: ref), "", .none)
        case .table(let node):
            let label = node["name"]?.stringValue ?? ""
            let meta = KeyBindingMeta(options: node)
            if case .table(let next)? = node["keys"] {
                // A key either opens more keys or runs one function.
                if node["fn"] != nil {
                    onLog("define_sequence('\(path)'): keys and fn, keys kept")
                    Self.releaseRefs(in: [node["fn"] ?? .none], lua: lua)
                }
                let keys = sequenceKeys(
                    next,
                    under: path,
                    leader: leader,
                    lua: lua
                )
                return (.opens(keys), label, meta)
            }
            if case .functionRef(let ref)? = node["fn"] {
                return (.run(ref: ref), label, meta)
            }
            return nil
        default:
            return nil
        }
    }

    /// Releases every function ref a refused value carries.
    private static func releaseRefs(in values: [LuaValue], lua: LuaInterpreter)
    {
        for value in values {
            switch value {
            case .functionRef(let ref): lua.release(ref: ref)
            case .table(let table):
                releaseRefs(in: Array(table.values), lua: lua)
            case .array(let array): releaseRefs(in: array, lua: lua)
            default: break
            }
        }
    }
}
