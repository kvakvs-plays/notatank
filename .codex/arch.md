# Notatank Architecture

Notatank is a World of Warcraft Classic TBC addon built around Ace3. The addon currently implements the loadable foundation from implementation steps 1 through 6: lifecycle setup, saved profile defaults, slash command routing, target priority data, and AceConfig controls for editing priority targets.

## Load Order

`Notatank-BCC.toc` embeds the required Ace3 libraries from `lib/` before loading addon modules from `src/`.

1. `src/Core.lua` creates the AceAddon instance on the shared addon namespace table.
2. `src/Config.lua` defines AceDB defaults and initializes `NotatankDB`.
3. `src/Targets.lua` defines raid mark metadata and priority-list helpers.
4. `src/Options.lua` registers the AceConfig options table and Interface Options entry.
5. `src/Commands.lua` registers `/notatank` and `/nt`.

## Runtime Shape

The addon namespace table is also the AceAddon object. Modules attach methods to that table and avoid globals. `Core.lua` calls module initialization methods from `OnInitialize` after all source files have loaded.

Saved data is profile-scoped through AceDB. Target priority data lives at `profile.targets.priority` as an ordered list of entries shaped like `{ type = "mark", mark = <1-8> }` or `{ type = "name", name = <monster name> }`. Older numeric or string priority entries are normalized into that shape during config initialization and through target helper accessors.

## Current Boundaries

No WoW macro writes, protected frame changes, targeting, or combat behavior exist yet. Slash commands and options only update saved settings or print status. `/nt target` reads the current target name, if one exists, and stores it as the top priority entry. Future macro and protected UI work should stay out of combat and queue updates until combat ends.

## Packaging

`wowaddon.py` packages only runtime addon files: `src/`, `lib/`, and root `.toc` files. `install` replaces the addon folder under a supplied WoW `Interface\AddOns` directory, and `zip` creates a release archive named from the checkout directory and the `local version = "..."` line in `src/Core.lua`.
