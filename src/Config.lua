---@type string, NotAddon
local addonName, addon = ...

local AceDB = LibStub("AceDB-3.0")

local defaults = {
	profile = {
		debug = false,
		targets = {
			captureEnabled = true,
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
		popup = {
			locked = true,
			positionPreset = "center",
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = 0,
			scale = 1,
		},
		overlays = {
			locked = true,
			scale = 1,
			opacity = 1,
			targetDebuffs = {
				enabled = true,
				preview = false,
				positionPreset = "left",
				point = "CENTER",
				relativePoint = "CENTER",
				x = -80,
				y = -140,
				spells = {
					thunderClap = true,
					demoralizingShout = true,
					sunderArmor = true,
					judgement = true,
					faerieFire = true,
					insectSwarm = false,
					demoralizingRoar = true,
					mangle = true,
					huntersMark = true,
					serpentSting = false,
					scorpidSting = false,
					vampiricTouch = true,
					vampiricEmbrace = false,
					shadowWordPain = true,
					corruption = true,
					immolate = false,
					curseOfDoom = false,
					curseOfAgony = true,
					curseOfElements = false,
				},
			},
			shouts = {
				enabled = true,
				preview = false,
				positionPreset = "right",
				point = "CENTER",
				relativePoint = "CENTER",
				x = 80,
				y = -190,
				warningSeconds = 15,
				spells = {
					battleShout = true,
					commandingShout = true,
					sliceAndDice = true,
					aspectOfTheHawk = true,
					aspectOfTheViper = false,
					demonSkin = false,
					demonArmor = false,
					felArmor = true,
					waterShield = true,
					lightningShield = false,
					mageArmor = false,
					moltenArmor = true,
					frostArmor = false,
				},
			},
		},
	},
}

function addon:InitializeConfig()
	self.db = AceDB:New("NotatankDB", defaults, true)
	self:NormalizeTargetPriority()
end

function addon:GetProfile()
	return self.db and self.db.profile
end

function addon:IsDebugEnabled()
	local profile = self:GetProfile()
	return profile and profile.debug
end
