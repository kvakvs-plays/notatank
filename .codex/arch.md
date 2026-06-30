# Notatank Architecture

Notatank is a World of Warcraft Classic TBC addon built around Ace3. The addon currently implements the loadable foundation from implementation steps 1 through 16: lifecycle setup, saved profile defaults, slash command routing, target priority data, safe macro maintenance, mouseover target capture, the combat target popup, tank reminder overlays, and setup diagnostics.

## Load Order

`Notatank-BCC.toc` embeds the required Ace3 libraries from `lib/` before loading addon modules from `src/`.

1. `src/Core.lua` creates the AceAddon instance on the shared addon namespace table.
2. `src/Config.lua` defines AceDB defaults and initializes `NotatankDB`.
3. `src/Targets.lua` defines raid mark metadata, priority-list helpers, and mouseover capture.
4. `src/Macro.lua` renders and maintains the addon-owned macro.
5. `src/Popup.lua` pre-creates secure target buttons and handles popup placement.
6. `src/Reminders.lua` creates movable reminder overlays, class debuff checks, and warrior shout checks.
7. `src/Options.lua` registers the AceConfig options table and Interface Options entry.
8. `src/Commands.lua` registers `/notatank` and `/nt`.

## Runtime Shape

The addon namespace table is also the AceAddon object. Modules attach methods to that table and avoid globals. `Core.lua` calls module initialization methods from `OnInitialize` after all source files have loaded.

Saved data is profile-scoped through AceDB. Target priority data lives at `profile.targets.priority` as an ordered list of entries shaped like `{ type = "mark", mark = <1-8> }` or `{ type = "name", name = <monster name> }`. Older numeric or string priority entries are normalized into that shape during config initialization and through target helper accessors.

Captured targets are in-memory only. `UPDATE_MOUSEOVER_UNIT` records hostile mouseover units outside combat when they match the configured priority list by raid mark or by name prefix. Candidates store name, raid mark, GUID-or-name key, priority rank, and last seen time, and are sorted by priority rank then recency.

The combat popup is a fixed pool of secure action buttons prepared out of combat from the captured target list. Button macro attributes are never changed in combat. Visibility is controlled by a secure state driver where available: the popup shows in combat when prepared candidates exist, otherwise it stays hidden. While unlocked, a placement visual is shown out of combat so the frame can be dragged and saved.

Reminder overlays are profile-scoped under `profile.overlays`. `src/Reminders.lua` owns two movable frames: target debuffs and warrior shouts. Target reminders check the current hostile target for enabled class debuffs: warrior Thunder Clap and Demoralizing Shout; paladin Judgement variants; bear druid Faerie Fire, Demoralizing Roar, and Mangle variants. Warrior shout reminders watch Battle Shout and Commanding Shout on the player, using aura caster data when available and recent player spellcast tracking as a best-effort ownership fallback.

## Current Boundaries

The addon owns one macro by configured name and marks its body with an ownership line before editing it later. Macro creation and edits only run out of combat; rebuild requests during combat are queued until `PLAYER_REGEN_ENABLED`. The macro body renders unique captured names as ordered `/tar [nodead] <name>` lines plus `/startattack`, truncating to the Classic macro body limit by keeping the highest-priority lines that fit.

Popup position, scale, and lock state live under `profile.popup`. Reminder position, scale, opacity, enabled spells, and shout warning thresholds live under `profile.overlays`. `/nt lock` and `/nt unlock` update popup and reminder lock state. Reminder protected spell buttons are pre-created and only rebound out of combat; combat-time aura changes may queue a protected-button refresh until combat ends.

`/nt status` is the primary in-game diagnostic surface. It reports target capture, configured priorities, captured candidates, macro state, popup state, reminder state, and queued combat updates. Macro creation failures, truncation, and in-combat rebuild queues are reported through concise addon chat messages.

## Packaging

`wowaddon.py` packages only runtime addon files: `src/`, `lib/`, and root `.toc` files. `install` replaces the addon folder under a supplied WoW `Interface\AddOns` directory, and `zip` creates a release archive named from the checkout directory and the `local version = "..."` line in `src/Core.lua`.
