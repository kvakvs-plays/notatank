---@type string, NotAddon
local addonName, addon = ...

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local optionsName = "Notatank"
local optionTable
local selectedRaidMark = 8
local selectedPriorityIndex
local pendingName = ""

local function getPath(rootKey, key)
	return function()
		local profile = addon:GetProfile()
		return profile and profile[rootKey] and profile[rootKey][key]
	end
end

local function setPath(rootKey, key)
	return function(_, value)
		local profile = addon:GetProfile()
		if profile and profile[rootKey] then
			profile[rootKey][key] = value
		end
	end
end

local function setMacroPath(key)
	return function(_, value)
		local profile = addon:GetProfile()
		if profile and profile.macro then
			profile.macro[key] = value
			if addon.RequestMacroRebuild then
				addon:RequestMacroRebuild("macro option changed")
			end
		end
	end
end

local function getPopupPath(key)
	return function()
		local profile = addon:GetProfile()
		return profile and profile.popup and profile.popup[key]
	end
end

local function setPopupLocked(_, value)
	if addon.SetPopupLocked then
		addon:SetPopupLocked(value)
	end
end

local function setPopupScale(_, value)
	if addon.SetPopupScale then
		addon:SetPopupScale(value)
	end
end

local function setPopupPositionPreset(_, value)
	if addon.SetPopupPositionPreset then
		addon:SetPopupPositionPreset(value)
	end
end

local function getNested(rootKey, groupKey, key)
	return function()
		local profile = addon:GetProfile()
		local root = profile and profile[rootKey]
		local group = root and root[groupKey]
		return group and group[key]
	end
end

local function setNested(rootKey, groupKey, key)
	return function(_, value)
		local profile = addon:GetProfile()
		local root = profile and profile[rootKey]
		local group = root and root[groupKey]
		if group then
			group[key] = value
		end
	end
end

local function setReminderLocked(_, value)
	if addon.SetRemindersLocked then
		addon:SetRemindersLocked(value)
	end
end

local function setReminderScale(_, value)
	if addon.SetReminderScale then
		addon:SetReminderScale(value)
	end
end

local function setReminderOpacity(_, value)
	if addon.SetReminderOpacity then
		addon:SetReminderOpacity(value)
	end
end

local function getPlayerClass()
	if type(UnitClass) ~= "function" then
		return nil
	end

	local _, classFile = UnitClass("player")
	return classFile
end

local function hiddenForClass(classFile)
	return function()
		local playerClass = getPlayerClass()
		return playerClass and playerClass ~= classFile
	end
end

local function getReminderSpell(groupKey, spellKey)
	return function()
		local profile = addon:GetProfile()
		local group = profile and profile.overlays and profile.overlays[groupKey]
		return not group or not group.spells or group.spells[spellKey] ~= false
	end
end

local function setReminderSpell(groupKey, spellKey)
	return function(_, value)
		local profile = addon:GetProfile()
		local group = profile and profile.overlays and profile.overlays[groupKey]
		if group then
			group.spells = group.spells or {}
			group.spells[spellKey] = value and true or false
			if addon.RefreshTargetDebuffs then
				addon:RefreshTargetDebuffs()
			end
			if addon.RefreshPlayerBuffs then
				addon:RefreshPlayerBuffs()
			end
		end
	end
end

local function getReminderPosition(kind)
	return function()
		local profile = addon:GetProfile()
		local group = profile and profile.overlays and profile.overlays[kind]
		return group and group.positionPreset or "center"
	end
end

local function setReminderPosition(kind)
	return function(_, value)
		if addon.SetReminderPositionPreset then
			addon:SetReminderPositionPreset(kind, value)
		end
	end
end

local function getSelectedPriorityIndex()
	local priority = addon:GetPriorityList()
	if selectedPriorityIndex and selectedPriorityIndex >= 1 and selectedPriorityIndex <= #priority then
		return selectedPriorityIndex
	end

	selectedPriorityIndex = nil
	return 0
end

local function prioritySelectionIsValid()
	return getSelectedPriorityIndex() ~= 0
end

local function addPriorityMark()
	local ok, index, label = addon:AddPriorityMark(selectedRaidMark, false)
	if ok then
		selectedPriorityIndex = index
		addon:Print(("Added priority target: %s."):format(label))
	else
		addon:Print(index)
	end
end

local function addPriorityName()
	local ok, index, label = addon:AddPriorityName(pendingName, false)
	if ok then
		pendingName = ""
		selectedPriorityIndex = index
		addon:Print(("Added priority target: %s."):format(label))
	else
		addon:Print(index)
	end
end

local function addCurrentTarget()
	local ok, index, label = addon:AddCurrentTargetToPriority(true)
	if ok then
		selectedPriorityIndex = index
		addon:Print(("Added priority target: %s."):format(label))
	else
		addon:Print(index)
	end
end

local function moveSelectedPriority(direction)
	local ok, indexOrMessage = addon:MovePriorityEntry(selectedPriorityIndex, direction)
	if ok then
		selectedPriorityIndex = indexOrMessage
	else
		addon:Print(indexOrMessage)
	end
end

local function deleteSelectedPriority()
	local removedIndex = selectedPriorityIndex
	local ok, message = addon:RemovePriorityEntry(removedIndex)
	if ok then
		local priority = addon:GetPriorityList()
		if #priority == 0 then
			selectedPriorityIndex = nil
		elseif removedIndex > #priority then
			selectedPriorityIndex = #priority
		else
			selectedPriorityIndex = removedIndex
		end
	else
		addon:Print(message)
	end
end

local function buildOptions()
	optionTable = {
		type = "group",
		name = addon.DISPLAY_NAME,
		childGroups = "tab",
		args = {
			targets = {
				type = "group",
				name = "Targets",
				order = 10,
				args = {
					captureEnabled = {
						type = "toggle",
						name = "Enable target capture",
						desc = "Enable future mouseover capture for configured priority targets.",
						order = 10,
						get = getPath("targets", "captureEnabled"),
						set = setPath("targets", "captureEnabled"),
					},
					raidMark = {
						type = "select",
						name = "Raid marks",
						desc = "Choose a raid mark to add to the priority list.",
						order = 20,
						style = "radio",
						values = function()
							return addon:GetRaidMarkOptionValues()
						end,
						get = function()
							return selectedRaidMark
						end,
						set = function(_, value)
							selectedRaidMark = value
						end,
					},
					addRaidMark = {
						type = "execute",
						name = "Add raid mark",
						desc = "Append the selected raid mark to the priority list.",
						order = 30,
						func = addPriorityMark,
					},
					priority = {
						type = "select",
						name = "Priority targets",
						desc = "Priority order used by later targeting behavior. Name entries may be partial names; matching will use the first letters of the unit name.",
						order = 40,
						style = "radio",
						values = function()
							return addon:GetPriorityOptionValues()
						end,
						get = getSelectedPriorityIndex,
						set = function(_, value)
							selectedPriorityIndex = value ~= 0 and value or nil
						end,
					},
					moveUp = {
						type = "execute",
						name = "Move up",
						desc = "Move the selected priority target earlier.",
						order = 50,
						disabled = function()
							return getSelectedPriorityIndex() <= 1
						end,
						func = function()
							moveSelectedPriority(-1)
						end,
					},
					moveDown = {
						type = "execute",
						name = "Move down",
						desc = "Move the selected priority target later.",
						order = 60,
						disabled = function()
							local priority = addon:GetPriorityList()
							local selected = getSelectedPriorityIndex()
							return selected == 0 or selected >= #priority
						end,
						func = function()
							moveSelectedPriority(1)
						end,
					},
					delete = {
						type = "execute",
						name = "Delete",
						desc = "Remove the selected priority target.",
						order = 70,
						disabled = function()
							return not prioritySelectionIsValid()
						end,
						func = deleteSelectedPriority,
					},
					name = {
						type = "input",
						name = "Monster name",
						desc = "Add a monster name priority. Partial names are accepted and will match the first letters of the unit name.",
						order = 80,
						get = function()
							return pendingName
						end,
						set = function(_, value)
							pendingName = value or ""
						end,
					},
					addName = {
						type = "execute",
						name = "Add name",
						desc = "Append the monster name to the priority list.",
						order = 90,
						disabled = function()
							return not pendingName:match("%S")
						end,
						func = addPriorityName,
					},
					addCurrent = {
						type = "execute",
						name = "Add current target",
						desc = "Add the current target's name as the top priority entry. This is safe in or out of combat because it only changes saved options.",
						order = 100,
						func = addCurrentTarget,
					},
					popupHeader = {
						type = "header",
						name = "Combat popup",
						order = 110,
					},
					popupLocked = {
						type = "toggle",
						name = "Lock popup",
						desc = "Lock or unlock the combat target popup. Slash commands: /nt lock and /nt unlock.",
						order = 120,
						get = getPopupPath("locked"),
						set = setPopupLocked,
					},
					popupScale = {
						type = "range",
						name = "Popup scale",
						desc = "Scale the combat target popup.",
						order = 130,
						min = 0.6,
						max = 2,
						step = 0.05,
						get = getPopupPath("scale"),
						set = setPopupScale,
					},
					popupPosition = {
						type = "select",
						name = "Popup position",
						desc = "Choose a starting position. Drag the popup while unlocked to save a custom position.",
						order = 140,
						values = {
							center = "Center",
							left = "Left",
							right = "Right",
							top = "Top",
							bottom = "Bottom",
							custom = "Custom",
						},
						get = function()
							local profile = addon:GetProfile()
							return profile and profile.popup and profile.popup.positionPreset or "center"
						end,
						set = setPopupPositionPreset,
					},
				},
			},
		},
	}

	optionTable.args.macro = {
		type = "group",
		name = "Macro",
		order = 20,
		args = {
			enabled = {
				type = "toggle",
				name = "Maintain macro",
				desc = "Create and update the addon-owned macro out of combat.",
				order = 10,
				get = getPath("macro", "enabled"),
				set = setMacroPath("enabled"),
			},
			name = {
				type = "input",
				name = "Macro name",
				desc = "Name reserved for the addon-owned macro.",
				order = 20,
				get = getPath("macro", "name"),
				set = setMacroPath("name"),
			},
			rebuildOnChanges = {
				type = "toggle",
				name = "Rebuild on changes",
				desc = "Rebuild the macro when configured priorities or captured targets change.",
				order = 30,
				get = getPath("macro", "rebuildOnChanges"),
				set = setPath("macro", "rebuildOnChanges"),
			},
			rebuild = {
				type = "execute",
				name = "Repair macro",
				desc = "Create or update the addon-owned macro now, if out of combat.",
				order = 40,
				func = function()
					local ok, message = addon:RequestMacroRebuild("manual repair")
					if ok then
						addon:Print("Macro repaired.")
					elseif message then
						addon:Print(message)
					end
				end,
			},
		},
	}

	optionTable.args.reminders = {
		type = "group",
		name = "Reminders",
		order = 30,
		args = {
			locked = {
				type = "toggle",
				name = "Lock frames",
				desc = "Locks the popup and reminder frames. Slash commands: /nt lock and /nt unlock.",
				order = 10,
				get = getPath("overlays", "locked"),
				set = setReminderLocked,
			},
			scale = {
				type = "range",
				name = "Scale",
				desc = "Scale for reminder overlays.",
				order = 20,
				min = 0.5,
				max = 2,
				step = 0.05,
				get = getPath("overlays", "scale"),
				set = setReminderScale,
			},
			opacity = {
				type = "range",
				name = "Opacity",
				desc = "Opacity for reminder overlays.",
				order = 30,
				min = 0.2,
				max = 1,
				step = 0.05,
				get = getPath("overlays", "opacity"),
				set = setReminderOpacity,
			},
			targetDebuffs = {
				type = "toggle",
				name = "Target debuff reminders",
				desc = "Show missing class debuffs on the current hostile target.",
				order = 40,
				get = getNested("overlays", "targetDebuffs", "enabled"),
				set = function(_, value)
					setNested("overlays", "targetDebuffs", "enabled")(_, value)
					if addon.RefreshTargetDebuffs then
						addon:RefreshTargetDebuffs()
					end
				end,
			},
			shouts = {
				type = "toggle",
				name = "Self buff reminders",
				desc = "Show a self-buff reminder when an enabled player buff is missing or near expiry.",
				order = 50,
				get = getNested("overlays", "shouts", "enabled"),
				set = function(_, value)
					setNested("overlays", "shouts", "enabled")(_, value)
					if addon.RefreshPlayerBuffs then
						addon:RefreshPlayerBuffs()
					end
				end,
			},
			targetPosition = {
				type = "select",
				name = "Target reminder position",
				desc = "Choose a starting position. Unlock and drag the frame to save a custom position.",
				order = 60,
				values = {
					left = "Left",
					center = "Center",
					right = "Right",
					custom = "Custom",
				},
				get = getReminderPosition("targetDebuffs"),
				set = setReminderPosition("targetDebuffs"),
			},
			shoutPosition = {
				type = "select",
				name = "Self buff reminder position",
				desc = "Choose a starting position. Unlock and drag the frame to save a custom position.",
				order = 70,
				values = {
					left = "Left",
					center = "Center",
					right = "Right",
					custom = "Custom",
				},
				get = getReminderPosition("shouts"),
				set = setReminderPosition("shouts"),
			},
			warriorHeader = {
				type = "header",
				name = "Warrior",
				order = 80,
				hidden = hiddenForClass("WARRIOR"),
			},
			thunderClap = {
				type = "toggle",
				name = "Thunder Clap",
				desc = "Remind when Thunder Clap is missing from the current hostile target.",
				order = 90,
				hidden = hiddenForClass("WARRIOR"),
				get = getReminderSpell("targetDebuffs", "thunderClap"),
				set = setReminderSpell("targetDebuffs", "thunderClap"),
			},
			demoralizingShout = {
				type = "toggle",
				name = "Demoralizing Shout",
				desc = "Remind when Demoralizing Shout is missing from the current hostile target.",
				order = 100,
				hidden = hiddenForClass("WARRIOR"),
				get = getReminderSpell("targetDebuffs", "demoralizingShout"),
				set = setReminderSpell("targetDebuffs", "demoralizingShout"),
			},
			sunderArmor = {
				type = "toggle",
				name = "Sunder Armor",
				desc = "Remind until Sunder Armor reaches 5 stacks on the current hostile target.",
				order = 105,
				hidden = hiddenForClass("WARRIOR"),
				get = getReminderSpell("targetDebuffs", "sunderArmor"),
				set = setReminderSpell("targetDebuffs", "sunderArmor"),
			},
			battleShout = {
				type = "toggle",
				name = "Battle Shout",
				desc = "Allow Battle Shout as a self-buff reminder.",
				order = 110,
				hidden = hiddenForClass("WARRIOR"),
				get = getReminderSpell("shouts", "battleShout"),
				set = setReminderSpell("shouts", "battleShout"),
			},
			commandingShout = {
				type = "toggle",
				name = "Commanding Shout",
				desc = "Allow Commanding Shout as a self-buff reminder.",
				order = 120,
				hidden = hiddenForClass("WARRIOR"),
				get = getReminderSpell("shouts", "commandingShout"),
				set = setReminderSpell("shouts", "commandingShout"),
			},
			paladinHeader = {
				type = "header",
				name = "Paladin",
				order = 130,
				hidden = hiddenForClass("PALADIN"),
			},
			judgement = {
				type = "toggle",
				name = "Judgement",
				desc = "Remind when Judgement is missing from the current hostile target.",
				order = 140,
				hidden = hiddenForClass("PALADIN"),
				get = getReminderSpell("targetDebuffs", "judgement"),
				set = setReminderSpell("targetDebuffs", "judgement"),
			},
			rogueHeader = {
				type = "header",
				name = "Rogue",
				order = 145,
				hidden = hiddenForClass("ROGUE"),
			},
			sliceAndDice = {
				type = "toggle",
				name = "Slice and Dice",
				desc = "Allow Slice and Dice as a self-buff reminder.",
				order = 146,
				hidden = hiddenForClass("ROGUE"),
				get = getReminderSpell("shouts", "sliceAndDice"),
				set = setReminderSpell("shouts", "sliceAndDice"),
			},
			hunterHeader = {
				type = "header",
				name = "Hunter",
				order = 150,
				hidden = hiddenForClass("HUNTER"),
			},
			huntersMark = {
				type = "toggle",
				name = "Hunter's Mark",
				desc = "Remind when Hunter's Mark is missing from the current hostile target.",
				order = 160,
				hidden = hiddenForClass("HUNTER"),
				get = getReminderSpell("targetDebuffs", "huntersMark"),
				set = setReminderSpell("targetDebuffs", "huntersMark"),
			},
			serpentSting = {
				type = "toggle",
				name = "Serpent Sting",
				desc = "Remind when Serpent Sting is missing from the current hostile target.",
				order = 170,
				hidden = hiddenForClass("HUNTER"),
				get = getReminderSpell("targetDebuffs", "serpentSting"),
				set = setReminderSpell("targetDebuffs", "serpentSting"),
			},
			scorpidSting = {
				type = "toggle",
				name = "Scorpid Sting",
				desc = "Remind when Scorpid Sting is missing from the current hostile target.",
				order = 180,
				hidden = hiddenForClass("HUNTER"),
				get = getReminderSpell("targetDebuffs", "scorpidSting"),
				set = setReminderSpell("targetDebuffs", "scorpidSting"),
			},
			aspectOfTheHawk = {
				type = "toggle",
				name = "Aspect of the Hawk",
				desc = "Allow Aspect of the Hawk as a self-buff reminder.",
				order = 181,
				hidden = hiddenForClass("HUNTER"),
				get = getReminderSpell("shouts", "aspectOfTheHawk"),
				set = setReminderSpell("shouts", "aspectOfTheHawk"),
			},
			aspectOfTheViper = {
				type = "toggle",
				name = "Aspect of the Viper",
				desc = "Allow Aspect of the Viper as a self-buff reminder.",
				order = 182,
				hidden = hiddenForClass("HUNTER"),
				get = getReminderSpell("shouts", "aspectOfTheViper"),
				set = setReminderSpell("shouts", "aspectOfTheViper"),
			},
			druidHeader = {
				type = "header",
				name = "Druid",
				order = 190,
				hidden = hiddenForClass("DRUID"),
			},
			faerieFire = {
				type = "toggle",
				name = "Faerie Fire",
				desc = "Remind when Faerie Fire is missing from the current hostile target.",
				order = 200,
				hidden = hiddenForClass("DRUID"),
				get = getReminderSpell("targetDebuffs", "faerieFire"),
				set = setReminderSpell("targetDebuffs", "faerieFire"),
			},
			insectSwarm = {
				type = "toggle",
				name = "Insect Swarm",
				desc = "Remind when Insect Swarm is missing from the current hostile target.",
				order = 210,
				hidden = hiddenForClass("DRUID"),
				get = getReminderSpell("targetDebuffs", "insectSwarm"),
				set = setReminderSpell("targetDebuffs", "insectSwarm"),
			},
			demoralizingRoar = {
				type = "toggle",
				name = "Demoralizing Roar",
				desc = "Remind when Demoralizing Roar is missing from the current hostile target while in bear form.",
				order = 220,
				hidden = hiddenForClass("DRUID"),
				get = getReminderSpell("targetDebuffs", "demoralizingRoar"),
				set = setReminderSpell("targetDebuffs", "demoralizingRoar"),
			},
			mangle = {
				type = "toggle",
				name = "Mangle",
				desc = "Remind when Mangle is missing from the current hostile target while in bear form.",
				order = 230,
				hidden = hiddenForClass("DRUID"),
				get = getReminderSpell("targetDebuffs", "mangle"),
				set = setReminderSpell("targetDebuffs", "mangle"),
			},
			priestHeader = {
				type = "header",
				name = "Shadow priest",
				order = 240,
				hidden = hiddenForClass("PRIEST"),
			},
			vampiricTouch = {
				type = "toggle",
				name = "Vampiric Touch",
				desc = "Remind when Vampiric Touch is missing from the current hostile target while in Shadowform.",
				order = 250,
				hidden = hiddenForClass("PRIEST"),
				get = getReminderSpell("targetDebuffs", "vampiricTouch"),
				set = setReminderSpell("targetDebuffs", "vampiricTouch"),
			},
			vampiricEmbrace = {
				type = "toggle",
				name = "Vampiric Embrace",
				desc = "Remind when Vampiric Embrace is missing from the current hostile target while in Shadowform.",
				order = 260,
				hidden = hiddenForClass("PRIEST"),
				get = getReminderSpell("targetDebuffs", "vampiricEmbrace"),
				set = setReminderSpell("targetDebuffs", "vampiricEmbrace"),
			},
			shadowWordPain = {
				type = "toggle",
				name = "Shadow Word: Pain",
				desc = "Remind when Shadow Word: Pain is missing from the current hostile target while in Shadowform.",
				order = 270,
				hidden = hiddenForClass("PRIEST"),
				get = getReminderSpell("targetDebuffs", "shadowWordPain"),
				set = setReminderSpell("targetDebuffs", "shadowWordPain"),
			},
			warlockHeader = {
				type = "header",
				name = "Warlock",
				order = 280,
				hidden = hiddenForClass("WARLOCK"),
			},
			corruption = {
				type = "toggle",
				name = "Corruption",
				desc = "Remind when Corruption is missing from the current hostile target.",
				order = 290,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("targetDebuffs", "corruption"),
				set = setReminderSpell("targetDebuffs", "corruption"),
			},
			immolate = {
				type = "toggle",
				name = "Immolate",
				desc = "Remind when Immolate is missing from the current hostile target.",
				order = 300,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("targetDebuffs", "immolate"),
				set = setReminderSpell("targetDebuffs", "immolate"),
			},
			curseOfDoom = {
				type = "toggle",
				name = "Curse of Doom",
				desc = "Remind when Curse of Doom is missing from the current hostile target.",
				order = 310,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("targetDebuffs", "curseOfDoom"),
				set = setReminderSpell("targetDebuffs", "curseOfDoom"),
			},
			curseOfAgony = {
				type = "toggle",
				name = "Curse of Agony",
				desc = "Remind when Curse of Agony is missing from the current hostile target.",
				order = 320,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("targetDebuffs", "curseOfAgony"),
				set = setReminderSpell("targetDebuffs", "curseOfAgony"),
			},
			curseOfElements = {
				type = "toggle",
				name = "Curse of the Elements",
				desc = "Remind when Curse of the Elements is missing from the current hostile target.",
				order = 330,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("targetDebuffs", "curseOfElements"),
				set = setReminderSpell("targetDebuffs", "curseOfElements"),
			},
			demonSkin = {
				type = "toggle",
				name = "Demon Skin",
				desc = "Allow Demon Skin as a self-buff reminder.",
				order = 331,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("shouts", "demonSkin"),
				set = setReminderSpell("shouts", "demonSkin"),
			},
			demonArmor = {
				type = "toggle",
				name = "Demon Armor",
				desc = "Allow Demon Armor as a self-buff reminder.",
				order = 332,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("shouts", "demonArmor"),
				set = setReminderSpell("shouts", "demonArmor"),
			},
			felArmor = {
				type = "toggle",
				name = "Fel Armor",
				desc = "Allow Fel Armor as a self-buff reminder.",
				order = 333,
				hidden = hiddenForClass("WARLOCK"),
				get = getReminderSpell("shouts", "felArmor"),
				set = setReminderSpell("shouts", "felArmor"),
			},
			mageHeader = {
				type = "header",
				name = "Mage",
				order = 340,
				hidden = hiddenForClass("MAGE"),
			},
			mageArmor = {
				type = "toggle",
				name = "Mage Armor",
				desc = "Allow Mage Armor as a self-buff reminder.",
				order = 350,
				hidden = hiddenForClass("MAGE"),
				get = getReminderSpell("shouts", "mageArmor"),
				set = setReminderSpell("shouts", "mageArmor"),
			},
			moltenArmor = {
				type = "toggle",
				name = "Molten Armor",
				desc = "Allow Molten Armor as a self-buff reminder.",
				order = 360,
				hidden = hiddenForClass("MAGE"),
				get = getReminderSpell("shouts", "moltenArmor"),
				set = setReminderSpell("shouts", "moltenArmor"),
			},
			frostArmor = {
				type = "toggle",
				name = "Frost Armor",
				desc = "Allow Frost Armor as a self-buff reminder.",
				order = 370,
				hidden = hiddenForClass("MAGE"),
				get = getReminderSpell("shouts", "frostArmor"),
				set = setReminderSpell("shouts", "frostArmor"),
			},
			shamanHeader = {
				type = "header",
				name = "Shaman",
				order = 380,
				hidden = hiddenForClass("SHAMAN"),
			},
			waterShield = {
				type = "toggle",
				name = "Water Shield",
				desc = "Allow Water Shield as a self-buff reminder.",
				order = 390,
				hidden = hiddenForClass("SHAMAN"),
				get = getReminderSpell("shouts", "waterShield"),
				set = setReminderSpell("shouts", "waterShield"),
			},
			lightningShield = {
				type = "toggle",
				name = "Lightning Shield",
				desc = "Allow Lightning Shield as a self-buff reminder.",
				order = 400,
				hidden = hiddenForClass("SHAMAN"),
				get = getReminderSpell("shouts", "lightningShield"),
				set = setReminderSpell("shouts", "lightningShield"),
			},
			warningSeconds = {
				type = "range",
				name = "Self buff warning seconds",
				desc = "Show self-buff reminders when an active player buff has this many seconds or less remaining.",
				order = 500,
				min = 5,
				max = 60,
				step = 1,
				get = getNested("overlays", "shouts", "warningSeconds"),
				set = function(_, value)
					setNested("overlays", "shouts", "warningSeconds")(_, value)
					if addon.RefreshPlayerBuffs then
						addon:RefreshPlayerBuffs()
					end
				end,
			},
		},
	}

	optionTable.args.help = {
		type = "group",
		name = "Help",
		order = 35,
		args = {
			flowHeader = {
				type = "header",
				name = "Targeting flow",
				order = 10,
			},
			flow = {
				type = "description",
				name = "Before combat, mouse over hostile mobs so Notatank can notice them. Only noticed mobs that match your configured priority raid marks or name prefixes are kept as target candidates.\n\nWhen you enter combat, prepared target buttons appear if any matching candidates were noticed. Clicking a popup target button targets that specific mob.\n\nClicking the Notatank macro runs captured targets in reverse priority order. WoW processes every /tar line, so the last successful target line wins and the highest-priority available target remains selected.",
				order = 20,
				fontSize = "medium",
			},
		},
	}

	return optionTable
end

function addon:InitializeOptions()
	local options = optionTable or buildOptions()
	options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
	options.args.profiles.name = "Profiles"
	options.args.profiles.order = 40

	AceConfig:RegisterOptionsTable(optionsName, options)
	AceConfigDialog:AddToBlizOptions(optionsName, addon.DISPLAY_NAME)
end

function addon:OpenOptions()
	AceConfigDialog:Open(optionsName)
end

function addon:NotifyOptionsChanged()
	AceConfigRegistry:NotifyChange(optionsName)
end
