local addonName, addon = ...

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local optionsName = "Notatank"
local optionTable

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
						desc = "Placeholder setting for the future mouseover target capture module.",
						order = 10,
						get = getPath("targets", "captureEnabled"),
						set = setPath("targets", "captureEnabled"),
					},
				},
			},
		},
	}

	optionTable.args.targets.args.placeholderRaidMark = {
		type = "range",
		name = "Placeholder raid mark",
		desc = "Saved placeholder for the later target priority controls.",
		order = 20,
		min = 1,
		max = 8,
		step = 1,
		get = getPath("targets", "placeholderRaidMark"),
		set = setPath("targets", "placeholderRaidMark"),
	}
	optionTable.args.targets.args.placeholderName = {
		type = "input",
		name = "Placeholder target name",
		desc = "Saved placeholder for the later target name priority list.",
		order = 30,
		get = getPath("targets", "placeholderName"),
		set = setPath("targets", "placeholderName"),
	}

	optionTable.args.macro = {
		type = "group",
		name = "Macro",
		order = 20,
		args = {
			enabled = {
				type = "toggle",
				name = "Maintain macro",
				desc = "Placeholder setting for future Notatank macro maintenance.",
				order = 10,
				get = getPath("macro", "enabled"),
				set = setPath("macro", "enabled"),
			},
			name = {
				type = "input",
				name = "Macro name",
				desc = "Name reserved for the addon-owned macro.",
				order = 20,
				get = getPath("macro", "name"),
				set = setPath("macro", "name"),
			},
			rebuildOnChanges = {
				type = "toggle",
				name = "Rebuild on changes",
				desc = "Placeholder setting for coalesced macro updates.",
				order = 30,
				get = getPath("macro", "rebuildOnChanges"),
				set = setPath("macro", "rebuildOnChanges"),
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
