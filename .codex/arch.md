# Notatank Architecture

Notatank is a World of Warcraft Classic TBC addon built around Ace3. The addon currently implements the loadable foundation from implementation steps 1 through 16: lifecycle setup, saved profile defaults, slash command routing, target priority data, safe macro maintenance, mouseover target capture, the combat target popup, tank reminder overlays, and setup diagnostics.

## Load Order

`Notatank-BCC.toc` embeds the required Ace3 libraries from `lib/` before loading addon modules from `src/`.

1. `src/Core.lua` creates the AceAddon instance on the shared addon namespace table.
2. `src/Config.lua` defines AceDB defaults and initializes `NotatankDB`.
3. `src/Targets.lua` defines raid mark metadata, priority-list helpers, and mouseover capture.
4. `src/Macro.lua` renders and maintains the addon-owned macro.
5. `src/Popup.lua` pre-creates secure target buttons and handles popup placement.
6. `src/Reminders.lua` creates movable reminder overlays, class debuff checks, and class-grouped self-buff checks.
7. `src/Options.lua` registers the AceConfig options table and Interface Options entry.
8. `src/Commands.lua` registers `/notatank` and `/nt`.

## Runtime Shape

The addon namespace table is also the AceAddon object. Modules attach methods to that table and avoid globals. `Core.lua` calls module initialization methods from `OnInitialize` after all source files have loaded.

Saved data is profile-scoped through AceDB. Target priority data lives at `profile.targets.priority` as an ordered list of entries shaped like `{ type = "mark", mark = <1-8> }` or `{ type = "name", name = <monster name> }`. Older numeric or string priority entries are normalized into that shape during config initialization and through target helper accessors.

Captured targets are in-memory only. `UPDATE_MOUSEOVER_UNIT` records hostile mouseover units outside combat when they match the configured priority list by raid mark or by name prefix. Candidates store name, raid mark, GUID-or-name key, priority rank, and last seen time, and are sorted by priority rank then recency.

The combat popup is a fixed pool of secure action buttons prepared out of combat from captured priority candidates. Button macro attributes are never changed in combat. Visibility is controlled by a secure state driver where available: the popup shows in combat when prepared candidates exist, otherwise it stays hidden. Clicking a popup button targets that clicked candidate. While unlocked, a placement visual is shown out of combat so the frame can be dragged and saved.

Reminder overlays are profile-scoped under `profile.overlays`. `src/Reminders.lua` owns two movable frames: target debuffs and self buffs. Target reminders are passive texture icons that can update during combat and check the current live hostile target for enabled class debuffs: warrior Thunder Clap, Demoralizing Shout, and Sunder Armor up to 5 stacks; paladin Judgement variants; druid Faerie Fire and Insect Swarm plus bear-only Demoralizing Roar and Mangle; hunter Hunter's Mark, Serpent Sting, and Scorpid Sting; shadow priest Vampiric Touch, Vampiric Embrace, and Shadow Word: Pain while in Shadowform; and warlock Corruption, Immolate, Curse of Doom, Curse of Agony, and Curse of the Elements. Self-buff reminders are also passive texture icons that update in and out of combat while watching class-grouped player buffs: warrior shouts, rogue Slice and Dice, hunter aspects, warlock armor buffs, shaman shields, and mage armor buffs. Self-buff reminders use aura caster data when available and recent player spellcast tracking as a best-effort ownership fallback.

## Current Boundaries

The addon owns one macro by configured name and marks its body with an ownership line before editing it later. Macro creation and edits only run out of combat; rebuild requests during combat are queued until `PLAYER_REGEN_ENABLED`. The macro keeps the highest-priority captured names that fit the Classic macro body limit, then emits `/tar [nodead] <name>` lines in reverse priority order followed by `/startattack`. WoW runs every `/tar` line in sequence, so the final successful target command wins and the highest-priority available captured target remains selected.

Popup position, scale, and lock state live under `profile.popup`. Reminder position, scale, opacity, enabled spells, and self-buff warning thresholds live under `profile.overlays`. The self-buff settings retain the existing `profile.overlays.shouts` key for profile compatibility. `/nt lock` and `/nt unlock` update popup and reminder lock state. Reminder icons update immediately because they are passive textures and do not use protected spell button attributes.

The Reminders options UI keeps shared frame controls visible and hides class-specific reminder toggles that do not match the current player class. The saved defaults remain broad so profile values are stable if a character changes class context or the options are inspected outside the WoW client.

`/nt status` is the primary in-game diagnostic surface. It reports target capture, configured priorities, captured candidates, macro state, popup state, reminder state, and queued combat updates. Macro creation failures, truncation, and in-combat rebuild queues are reported through concise addon chat messages.

## Packaging

`wowaddon.py` packages only runtime addon files: `src/`, `lib/`, and root `.toc` files. `install` replaces the addon folder under a supplied WoW `Interface\AddOns` directory, and `zip` creates a release archive named from the checkout directory and the `local version = "..."` line in `src/Core.lua`.
