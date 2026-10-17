import Foundation

/// `kiwidesk completion zsh|bash|fish`: prints a shim that asks
/// `kiwidesk __complete` for every completion (#1685 ▸ Ruling 6e).
/// The shim holds no command names, so it never goes stale; it calls
/// the binary under the name the user typed.
enum CLICompletion {
    static let verb = "completion"

    /// The shells a shim exists for; completion offers them too.
    enum Shell: String, CaseIterable {
        case zsh, bash, fish

        var script: String {
            switch self {
            case .zsh: return CLICompletion.zsh
            case .bash: return CLICompletion.bash
            case .fish: return CLICompletion.fish
            }
        }
    }

    static var usage: String {
        "usage: kiwidesk completion "
            + Shell.allCases.map(\.rawValue).joined(separator: "|")
    }

    static func run(_ arguments: [String]) -> Int32 {
        guard
            arguments.count == 3,
            let shell = Shell(rawValue: arguments[2])
        else {
            FileHandle.standardError.write(Data("\(usage)\n".utf8))
            return 1
        }
        print(shell.script, terminator: "")
        return 0
    }

    /// Autoloaded from `fpath` as `_kiwidesk`, or sourced. The
    /// typed words are unquoted (`Q`), and the current one loses an
    /// opening quote, so a quoted name still matches; after
    /// `watch … --` the rest completes as a command line of its own
    /// (`_normal`).
    static let zsh = #"""
        #compdef kiwidesk
        _kiwidesk() {
          local -a candidates
          local typed=${(Q)${words[CURRENT]#[\"\']}}
          candidates=(${(f)"$("${words[1]}" \#(CLICompleter.verb) \#
        "${(@Q)words[2,CURRENT-1]}" "$typed" 2>/dev/null)"})
          if [[ "${candidates[1]}" == "\#(CLICompleter.defaultDirective)" ]]
          then
            local split=${words[(i)--]}
            shift $split words
            (( CURRENT -= split ))
            _normal
            return
          fi
          compadd -- "${candidates[@]}"
        }
        if [[ "${funcstack[1]}" == "_kiwidesk" ]]; then
          _kiwidesk "$@"
        else
          compdef _kiwidesk kiwidesk
        fi

        """#

    /// Sourced or eval'd. The word being completed loses a leading
    /// quote and its backslashes before it is asked about; after
    /// `watch … --` the next word completes as a command, the rest
    /// as files.
    static let bash = #"""
        # Inside an open quote readline adds the closing quote;
        # escaping there would put a backslash in the name.
        __kiwidesk_quote() {
          if [[ "$cur" == [\"\']* ]]; then printf '%s' "$1"
          else printf '%q' "$1"; fi
        }
        _kiwidesk() {
          local cur="${COMP_WORDS[COMP_CWORD]}" line i
          local typed="${cur#[\"\']}"
          typed="${typed//\\/}"
          COMPREPLY=()
          while IFS= read -r line; do
            if [[ "$line" == "\#(CLICompleter.defaultDirective)" ]]; then
              for (( i = 1; i < COMP_CWORD; i++ )); do
                [[ "${COMP_WORDS[i]}" == "--" ]] && break
              done
              local kind=-f
              (( i == COMP_CWORD - 1 )) && kind=-c
              while IFS= read -r line; do
                COMPREPLY+=("$(__kiwidesk_quote "$line")")
              done < <(compgen $kind -- "$typed")
              return
            fi
            [[ -n "$line" ]] && COMPREPLY+=("$(__kiwidesk_quote "$line")")
          done < <("${COMP_WORDS[0]}" \#(CLICompleter.verb) \#
        "${COMP_WORDS[@]:1:COMP_CWORD-1}" "$typed" 2>/dev/null)
        }
        complete -F _kiwidesk kiwidesk

        """#

    /// Dropped into `~/.config/fish/completions/kiwidesk.fish`. After
    /// `watch … --` the rest completes as a command line of its own.
    static let fish = #"""
        function __kiwidesk_complete
            set -l cur (commandline -ct | string unescape)
            or set cur (commandline -ct)
            set -l tokens (commandline -opc) "$cur"
            set -l out ($tokens[1] \#(CLICompleter.verb) $tokens[2..-1] \#
        2>/dev/null)
            if test "$out[1]" = "\#(CLICompleter.defaultDirective)"
                set -l split (contains -i -- -- $tokens)
                __fish_complete_subcommand --fcs-skip=$split
                return
            end
            printf '%s\n' $out
        end
        complete -c kiwidesk -f -a '(__kiwidesk_complete)'

        """#
}
