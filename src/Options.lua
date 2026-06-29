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
				desc = "Controls the current placeholder lock state. Slash commands: /nt lock and /nt unlock.",
				order = 10,
				get = getPath("overlays", "locked"),
				set = setPath("overlays", "locked"),
			},
			scale = {
				type = "range",
				name = "Scale",
				desc = "Saved placeholder scale for reminder overlays.",
				order = 20,
				min = 0.5,
				max = 2,
				step = 0.05,
				get = getPath("overlays", "scale"),
				set = setPath("overlays", "scale"),
			},
			opacity = {
				type = "range",
				name = "Opacity",
				desc = "Saved placeholder opacity for reminder overlays.",
				order = 30,
				min = 0.2,
				max = 1,
				step = 0.05,
				get = getPath("overlays", "opacity"),
				set = setPath("overlays", "opacity"),
			},
			targetDebuffs = {
				type = "toggle",
				name = "Target debuff reminders",
				desc = "Placeholder setting for future target debuff reminders.",
				order = 40,
				get = getNested("overlays", "targetDebuffs", "enabled"),
				set = setNested("overlays", "targetDebuffs", "enabled"),
			},
			shouts = {
				type = "toggle",
				name = "Warrior shout reminders",
				desc = "Placeholder setting for future warrior shout reminders.",
				order = 50,
				get = getNested("overlays", "shouts", "enabled"),
				set = setNested("overlays", "shouts", "enabled"),
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
