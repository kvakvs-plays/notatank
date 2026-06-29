local addonName, addon = ...

local AceDB = LibStub("AceDB-3.0")

local defaults = {
	profile = {
		debug = false,
		targets = {
			captureEnabled = true,
			placeholderName = "",
			placeholderRaidMark = 1,
			enabledMarks = {
				[1] = true,
				[2] = true,
				[3] = true,
				[4] = true,
				[5] = true,
				[6] = true,
				[7] = true,
				[8] = true,
			},
			priority = {},
		},
		macro = {
			enabled = true,
			name = "Notatank",
			rebuildOnChanges = true,
		},
		overlays = {
			locked = true,
			scale = 1,
			opacity = 1,
			targetDebuffs = {
				enabled = true,
				preview = false,
			},
			shouts = {
				enabled = true,
				preview = false,
			},
		},
	},
}

function addon:InitializeConfig()
	self.db = AceDB:New("NotatankDB", defaults, true)
end

function addon:GetProfile()
	return self.db and self.db.profile
end

function addon:IsDebugEnabled()
	local profile = self:GetProfile()
	return profile and profile.debug
end
