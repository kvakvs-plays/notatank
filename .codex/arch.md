# Notatank Architecture

Notatank is a World of Warcraft Classic TBC addon built around Ace3. The addon currently implements the loadable foundation from implementation steps 1 through 9: lifecycle setup, saved profile defaults, slash command routing, target priority data, safe macro maintenance, and mouseover target capture.

## Load Order

`Notatank-BCC.toc` embeds the required Ace3 libraries from `lib/` before loading addon modules from `src/`.

1. `src/Core.lua` creates the AceAddon instance on the shared addon namespace table.
2. `src/Config.lua` defines AceDB defaults and initializes `NotatankDB`.
3. `src/Targets.lua` defines raid mark metadata, priority-list helpers, and mouseover capture.
4. `src/Macro.lua` renders and maintains the addon-owned macro.
5. `src/Options.lua` registers the AceConfig options table and Interface Options entry.
6. `src/Commands.lua` registers `/notatank` and `/nt`.

## Runtime Shape

The addon namespace table is also the AceAddon object. Modules attach methods to that table and avoid globals. `Core.lua` calls module initialization methods from `OnInitialize` after all source files have loaded.

Saved data is profile-scoped through AceDB. Target priority data lives at `profile.targets.priority` as an ordered list of entries shaped like `{ type = "mark", mark = <1-8> }` or `{ type = "name", name = <monster name> }`. Older numeric or string priority entries are normalized into that shape during config initialization and through target helper accessors.

Captured targets are in-memory only. `UPDATE_MOUSEOVER_UNIT` records hostile mouseover units outside combat when they match the configured priority list by raid mark or by name prefix. Candidates store name, raid mark, GUID-or-name key, priority rank, and last seen time, and are sorted by priority rank then recency.

## Current Boundaries

The addon owns one macro by configured name and marks its body with an ownership line before editing it later. Macro creation and edits only run out of combat; rebuild requests during combat are queued until `PLAYER_REGEN_ENABLED`. The macro body renders unique captured names as ordered `/tar [nodead] <name>` lines plus `/startattack`, truncating to the Classic macro body limit by keeping the highest-priority lines that fit.

No protected popup frames, combat targeting buttons, or reminder behavior exist yet. `/nt target` reads the current target name, if one exists, and stores it as the top priority entry.

## Packaging

`wowaddon.py` packages only runtime addon files: `src/`, `lib/`, and root `.toc` files. `install` replaces the addon folder under a supplied WoW `Interface\AddOns` directory, and `zip` creates a release archive named from the checkout directory and the `local version = "..."` line in `src/Core.lua`.
