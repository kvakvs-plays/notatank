# Notatank Implementation Steps

## Rules For Every Step
- Keep the addon loadable/playable after each step.
- Update `.codex/arch.md` and `.codex/map.md` whenever files or module responsibilities change.
- Run Lua syntax checks after each Lua-writing step when available.
- Avoid implementing combat-time mutation of protected frames or macros; queue those updates until out of combat.

## Step 1: Add Minimal Addon Skeleton
Create `Notatank-BCC.toc`, `src/Core.lua`, `src/Config.lua`, and initial `.codex` docs. Load embedded Ace3 from `lib/`, create the AceAddon instance, initialize AceDB defaults, and print a short loaded message only when debug mode is enabled.

Playable state: addon loads with no visible features and no Lua errors.

## Step 2: Add Slash Command Shell
Add `src/Commands.lua` with `/notatank` and `/nt`. Implement `status`, `lock`, `unlock`, and unknown-command help as harmless stubs.

Playable state: commands work in chat, but no UI or targeting behavior is required yet.

## Step 3: Add Options Window Shell
Add `src/Options.lua` using AceConfig/AceConfigDialog. Create tabs for `Targets`, `Macro`, `Reminders`, and `Profiles`, with placeholder controls backed by AceDB defaults.

Playable state: `/nt` or `/notatank` opens the options window; changing placeholder settings persists after reload.

## Step 4: Implement Priority Target Data Model
Add target priority storage under `targets.priority`. Support entries of type `mark` and `name`, with add/remove/up/down helpers. Add default raid mark metadata and stable labels.

Playable state: options can display and reorder priority entries, but they do not affect targeting yet.

## Step 5: Implement Target Options Controls
Fill the `Targets` tab with the eight raid marks list, selected priority list, up/down/delete controls, text input for monster names, and an “add current target” action that calls a stub-safe helper.

Playable state: users can configure priority targets entirely through options without combat behavior.

## Step 6: Implement `/nt target`
Wire `/nt target` to add the current target’s name as the top priority entry when a target exists. Print a concise error if there is no target.

Playable state: command updates options data and remains safe in or out of combat.

## Step 7: Add Macro Module With Rendering Only
Add `src/Macro.lua` with macro-name settings, macro ownership constants, and a pure renderer that produces ordered `/tar [nodead] <name>` lines plus `/startattack`.

Playable state: no real macro writes yet; `/nt status` can show the rendered preview or target count.

## Step 8: Add Safe Macro Creation And Update
Implement out-of-combat macro discovery, creation, and updates. Never overwrite unrelated macros. Queue rebuild requests during combat and apply after `PLAYER_REGEN_ENABLED`.

Playable state: configured macro is maintained out of combat and combat attempts do not cause blocked-action errors.

## Step 9: Add Mouseover Capture
Add `src/Targets.lua` event handling for mouseover hostile units before combat. Capture only units matching selected priority raid marks or configured names. Store name, mark, GUID fallback key, priority rank, and last seen time.

Playable state: mouseover capture updates internal state and macro rebuilds out of combat; no popup UI yet.

## Step 10: Add Secure Popup Frame Skeleton
Add `src/Popup.lua` with a fixed pool of pre-created secure target buttons. Configure button attributes only out of combat, show the popup only in combat when candidates exist, and hide otherwise.

Playable state: entering combat with captured candidates shows clickable target buttons; no dynamic in-combat rebuilding.

## Step 11: Add Popup Positioning And Locking
Add popup position/scale/lock settings, drag-to-move while unlocked, and `/nt lock`/`/nt unlock` support. Mention these commands in the `Reminders` or layout-related options text.

Playable state: popup remains usable and position persists after reload.

## Step 12: Add Reminder Overlay Frames
Add `src/Reminders.lua` with two movable icon frames: target debuff reminder and warrior shout reminder. Implement lock/unlock, position presets, scale, and opacity without actual aura logic yet.

Playable state: overlay frames can be previewed, moved, locked, and hidden without affecting combat.

## Step 13: Implement Target Debuff Reminders
Add class-based target debuff checks:
- Warrior: Thunder Clap and Demoralizing Shout.
- Paladin: Judgement.
- Bear druid: Faerie Fire, Demoralizing Roar, and Mangle.

Show all enabled missing debuff icons for the current hostile target. Hide when no applicable target exists or all enabled debuffs are present.

Playable state: reminder icons reflect current target aura state and never block targeting/combat.

## Step 14: Add Protected Debuff Cast Buttons
Pre-create hidden protected buttons for enabled debuff reminders out of combat. Make reminder icons clickable where possible by binding safe spell attributes before combat.

Playable state: icons can be clicked in combat only if their protected attributes were prepared before combat; otherwise they display as reminders only.

## Step 15: Implement Warrior Shout Reminder
Track Battle Shout and Commanding Shout in combat. Show countdown near expiry, show missing-shout reminder when only another warrior’s shout appears active, and hide once the player’s own shout is healthy. Use best-effort ownership tracking if Classic aura caster data is incomplete.

Playable state: warrior reminder is useful but conservative; missing ownership data must not spam false positives.

## Step 16: Polish Status And Failure Feedback
Expand `/nt status` to report configured priorities, captured candidates, macro state, popup lock state, reminder mode, and any queued combat updates. Add clear chat messages for full macro slots, macro truncation, and blocked in-combat rebuilds.

Playable state: users can diagnose common setup issues from chat output.

## Step 17: Final Verification Pass
Run Lua syntax checks for all source files. In-game, verify load, slash commands, options persistence, target priority ordering, mouseover capture, macro rebuilds, combat popup clicks, overlay positioning, class reminders, and combat queue behavior.

Playable state: feature set from `plan.md` is complete enough for normal Classic TBC playtesting.
