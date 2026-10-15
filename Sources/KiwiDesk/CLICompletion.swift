import Foundation

/// `kiwidesk completion zsh|bash|fish`: prints a shim that asks
/// `kiwidesk __complete` for every completion (#1685 ▸ Ruling 6e).
/// The shim holds no command names, so it never goes stale; it calls
/// the binary under the name the user typed.
enum CLICompletion {
    static let verb = "completion"

    static let usage = "usage: kiwidesk completion zsh|bash|fish"

    static func run(_ arguments: [String]) -> Int32 {
        guard
            arguments.count == 3,
            let script = script(for: arguments[2])
        else {
            FileHandle.standardError.write(Data("\(usage)\n".utf8))
            return 1
        }
        print(script, terminator: "")
        return 0
    }

    static func script(for shell: String) -> String? {
        switch shell {
        case "zsh": return zsh
        case "bash": return bash
        case "fish": return fish
        default: return nil
        }
    }

    /// Autoloaded from `fpath` as `_kiwidesk`, or sourced.
    static let zsh = """
        #compdef kiwidesk
        _kiwidesk() {
          local -a candidates
          candidates=(${(f)"$("${words[1]}" \(CLICompleter.verb) \
        "${(@)words[2,CURRENT]}" 2>/dev/null)"})
          if [[ "${candidates[1]}" == "\(CLICompleter.defaultDirective)" ]]
          then
            _default
            return
          fi
          compadd -- "${candidates[@]}"
        }
        if [[ "${funcstack[1]}" == "_kiwidesk" ]]; then
          _kiwidesk "$@"
        else
          compdef _kiwidesk kiwidesk
        fi

        """

    /// Sourced, or dropped into `bash-completion`'s directory.
    /// `-o default` lets a `watch` command complete as files.
    static let bash = """
        _kiwidesk() {
          local cur="${COMP_WORDS[COMP_CWORD]}" line
          COMPREPLY=()
          while IFS= read -r line; do
            [[ "$line" == "\(CLICompleter.defaultDirective)" ]] && return
            [[ -n "$line" ]] && COMPREPLY+=("$(printf '%q' "$line")")
          done < <("${COMP_WORDS[0]}" \(CLICompleter.verb) \
        "${COMP_WORDS[@]:1:COMP_CWORD}" 2>/dev/null)
        }
        complete -o default -F _kiwidesk kiwidesk

        """

    /// Dropped into `~/.config/fish/completions/kiwidesk.fish`.
    static let fish = """
        function __kiwidesk_complete
            set -l tokens (commandline -opc) (commandline -ct)
            set -l out ($tokens[1] \(CLICompleter.verb) $tokens[2..-1] \
        2>/dev/null)
            if test "$out[1]" = "\(CLICompleter.defaultDirective)"
                __fish_complete_path (commandline -ct)
                return
            end
            printf '%s\\n' $out
        end
        complete -c kiwidesk -f -a '(__kiwidesk_complete)'

        """
}
