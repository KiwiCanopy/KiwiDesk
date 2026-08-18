---
title: Miscellaneous Integrations
description: Shell scripts, event streaming, Hammerspoon, and
  per-Desktop keybindings.
---

# Miscellaneous Integrations

## Shell scripts & event streaming

Any process can subscribe to KiwiDesk events as newline-delimited
JSON:

```sh
KIWIDESK=kiwidesk   # or a source build's full path

"$KIWIDESK" subscribe space_change | while read -r line; do
    space=$(echo "$line" | jq -r '.data.space_id')
    echo "switched to space $space"
done
```

Query state on demand:

```sh
# List all spaces and their layout modes:
"$KIWIDESK" get_state | jq '.spaces[] | {id, mode}'

# List monitors:
"$KIWIDESK" list_monitors | jq
```

The event stream is useful for durable external daemons, shell
functions, or tools that run in a different sandbox than
KiwiDesk. Each event has an `event` field (e.g.,
`"space_change"`) and a `data` object with fields matching the
Lua callback arguments
(e.g., `space_id`, `mode`).

## Hammerspoon

Drive KiwiDesk from Hammerspoon (or vice versa) through the CLI
(see the [recipes intro](index.md) for the binary path):

```lua
-- Absolute: Hammerspoon is a GUI app, so its os.execute inherits
-- launchd's minimal PATH without /opt/homebrew/bin. Swap in your
-- clone's path if you built from source.
local KIWIDESK = "/opt/homebrew/bin/kiwidesk"

hs.hotkey.bind({"cmd", "alt"}, "m", function()
    os.execute("'" .. KIWIDESK .. "' set_mode monocle")
end)
```

Or set up space switching via KiwiDesk:

```lua
hs.hotkey.bind({"cmd", "alt"}, "1", function()
    os.execute("'" .. KIWIDESK .. "' focus_space 1")
end)
```

**Tip:** KiwiDesk's own modal keybindings (see
[configuration](../lua-reference.md)) cover most Hammerspoon
window-management use cases natively, and they do not require
another daemon. If you are already running Hammerspoon for
other reasons, the CLI bridge above lets you invoke KiwiDesk
commands without duplicating logic.

## Per-Desktop keybindings (hand-written configs)

> **Native support exists now:** A profile can carry a sparse
> `"layers"` override that shadows individual base shortcuts.
> Combined with `bind_profile_to_native_space`, each Desktop
> gets its own layouts and its own keybinds with no Lua code.
> See *Config cascade* under
> [Keybindings](../lua-reference.md). This recipe remains for
> hand-written (non-GUI-managed) configs, where Lua owns all
> keybindings.

For a hand-written config, combine shortcut layers with the
`native_space_change` event. Only the active layer's bindings
fire, so build each Desktop's layer by merging shared binds with
per-Desktop overrides:

```lua
-- Shared binds, active in every layer:
local common = {
    ["cmd+alt+1"] = function()
        KiwiDesk.focus_space("1")
    end,
    ["cmd+alt+2"] = function()
        KiwiDesk.focus_space("2")
    end,
    ["cmd+alt+left"] = function()
        KiwiDesk.focus("left")
    end,
    ["cmd+alt+right"] = function()
        KiwiDesk.focus("right")
    end,
    -- ... other shared binds
}

-- Helper: merge common binds with per-layer overrides.
local function layer(overrides)
    local merged = {}
    for k, v in pairs(common) do
        merged[k] = v
    end
    for k, v in pairs(overrides) do
        merged[k] = v
    end
    return merged
end

-- Desktop 1: standard binds, no overrides.
KiwiDesk.define_layer("desk1", layer({}))

-- Desktop 2: override cmd+alt+m to enter the monocle layout.
KiwiDesk.define_layer("desk2", layer({
    ["cmd+alt+m"] = function()
        KiwiDesk.set_mode("monocle")
    end,
}))

-- Switch layer when the macOS Desktop changes. Only the main
-- display's Desktop counts ("Displays have separate Spaces"
-- makes secondary screens report their own switches too):
KiwiDesk.on("native_space_change", function(n, monitor)
    if monitor ~= 1 then return end
    KiwiDesk.switch_layer(n == 2 and "desk2" or "desk1")
end)

-- Start on Desktop 1.
KiwiDesk.switch_layer("desk1")
```

Pair this with `bind_profile_to_native_space` (see
[configuration](../lua-reference.md)) and each Desktop gets
its own layouts *and* its own keybinds.
