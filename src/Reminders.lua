---@type string, NotAddon
local addonName, addon = ...

local ICON_SIZE = 34
local ICON_GAP = 5
local TARGET_BUTTON_COUNT = 4
local SHOUT_BUTTON_COUNT = 1
local DEFAULT_WARNING_SECONDS = 15

local targetDebuffsByClass = {
	WARRIOR = {
		{ key = "thunderClap", spell = "Thunder Clap", icon = "Interface\\Icons\\Spell_Nature_ThunderClap" },
		{ key = "demoralizingShout", spell = "Demoralizing Shout", icon = "Interface\\Icons\\Ability_Warrior_WarCry" },
	},
	PALADIN = {
		{ key = "judgement", spell = "Judgement", icon = "Interface\\Icons\\Spell_Holy_RighteousFury" },
	},
	DRUID = {
		{ key = "faerieFire", spell = "Faerie Fire", icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
		{ key = "insectSwarm", spell = "Insect Swarm", icon = "Interface\\Icons\\Spell_Nature_InsectSwarm" },
		{ key = "demoralizingRoar", spell = "Demoralizing Roar", icon = "Interface\\Icons\\Ability_Druid_DemoralizingRoar", requires = "bearForm" },
		{ key = "mangle", spell = "Mangle", icon = "Interface\\Icons\\Ability_Druid_Mangle2", requires = "bearForm" },
	},
	HUNTER = {
		{ key = "huntersMark", spell = "Hunter's Mark", icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
		{ key = "serpentSting", spell = "Serpent Sting", icon = "Interface\\Icons\\Ability_Hunter_Quickshot" },
		{ key = "scorpidSting", spell = "Scorpid Sting", icon = "Interface\\Icons\\Ability_Hunter_CriticalShot" },
	},
	PRIEST = {
		{ key = "vampiricTouch", spell = "Vampiric Touch", icon = "Interface\\Icons\\Spell_Holy_Stoicism", requires = "shadowForm" },
		{ key = "vampiricEmbrace", spell = "Vampiric Embrace", icon = "Interface\\Icons\\Spell_Shadow_UnsummonBuilding", requires = "shadowForm" },
		{ key = "shadowWordPain", spell = "Shadow Word: Pain", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", requires = "shadowForm" },
	},
}

local warriorShouts = {
	{ key = "battleShout", spell = "Battle Shout", icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
	{ key = "commandingShout", spell = "Commanding Shout", icon = "Interface\\Icons\\Ability_Warrior_RallyingCry" },
}

local reminders = {
	frames = {},
	targetMissingCount = 0,
	shoutActive = false,
	lastOwnShoutSpell = nil,
	lastOwnShoutTime = 0,
}

addon.REMINDER_TARGET_BUTTON_COUNT = TARGET_BUTTON_COUNT
addon.REMINDER_SHOUT_BUTTON_COUNT = SHOUT_BUTTON_COUNT

local function isInCombat()
	return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getNow()
	if type(GetTime) == "function" then
		return GetTime()
	end

	return 0
end

local function getPlayerClass()
	if type(UnitClass) ~= "function" then
		return nil
	end

	local _, classFile = UnitClass("player")
	return classFile
end

local function getSpellIcon(spell, fallback)
	if type(GetSpellTexture) == "function" then
		local texture = GetSpellTexture(spell)
		if texture then
			return texture
		end
	end

	return fallback
end

local function getOverlaySettings()
	local profile = addon:GetProfile()
	if not profile then
		return nil
	end

	profile.overlays = profile.overlays or {}
	local overlays = profile.overlays
	overlays.locked = overlays.locked ~= false
	overlays.scale = overlays.scale or 1
	overlays.opacity = overlays.opacity or 1
	return overlays
end

local function getFrameSettings(kind)
	local overlays = getOverlaySettings()
	if not overlays then
		return nil
	end

	local settings = overlays[kind]
	if type(settings) ~= "table" then
		settings = {}
		overlays[kind] = settings
	end

	settings.point = settings.point or (kind == "targetDebuffs" and "CENTER" or "CENTER")
	settings.relativePoint = settings.relativePoint or settings.point
	settings.x = settings.x or (kind == "targetDebuffs" and -80 or 80)
	settings.y = settings.y or -140
	settings.positionPreset = settings.positionPreset or (kind == "targetDebuffs" and "left" or "right")

	return settings
end

local function frameWidth(buttonCount)
	return (ICON_SIZE * buttonCount) + (ICON_GAP * (buttonCount - 1))
end

local function setRegionShown(region, shown)
	if not region then
		return
	end

	if shown then
		region:Show()
	else
		region:Hide()
	end
end

local function unitExists(unit)
	return type(UnitExists) == "function" and UnitExists(unit)
end

local function unitIsHostile(unit)
	if type(UnitReaction) == "function" then
		local reaction = UnitReaction(unit, "player")
		return type(reaction) == "number" and reaction <= 3
	end

	return type(UnitCanAttack) == "function" and UnitCanAttack("player", unit)
end

local function unitIsDead(unit)
	return type(UnitIsDead) == "function" and UnitIsDead(unit)
end

local function isBearForm()
	if getPlayerClass() ~= "DRUID" then
		return false
	end

	if type(GetShapeshiftFormID) ~= "function" then
		return false
	end

	local formId = GetShapeshiftFormID()
	return (BEAR_FORM ~= nil and formId == BEAR_FORM) or formId == 8
end

local function auraNameMatches(actual, wanted)
	if type(actual) ~= "string" or type(wanted) ~= "string" then
		return false
	end

	local actualLower = actual:lower()
	local wantedLower = wanted:lower()
	return actualLower == wantedLower or actualLower:sub(1, #wantedLower) == wantedLower
end

local function findAura(unit, spell, filter)
	local auraFunc = filter == "HELPFUL" and UnitBuff or UnitDebuff
	if type(auraFunc) == "function" then
		for index = 1, 40 do
			local name, rank, icon, count, debuffType, duration, expirationTime, caster = auraFunc(unit, index)
			if not name then
				break
			end
			if auraNameMatches(name, spell) then
				return {
					name = name,
					icon = icon,
					duration = duration,
					expirationTime = expirationTime,
					caster = caster,
				}
			end
		end
	end

	if type(UnitAura) == "function" then
		for index = 1, 40 do
			local name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitAura(unit, index, filter)
			if not name then
				break
			end
			if auraNameMatches(name, spell) then
				return {
					name = name,
					icon = icon,
					duration = duration,
					expirationTime = expirationTime,
					caster = caster,
				}
			end
		end
	end

	return nil
end

local function isShadowForm()
	return findAura("player", "Shadowform", "HELPFUL") ~= nil
end

local function requirementMet(requirement)
	if requirement == "bearForm" then
		return isBearForm()
	elseif requirement == "shadowForm" then
		return isShadowForm()
	end

	return true
end

local function spellEnabled(settings, key)
	return not settings.spells or settings.spells[key] ~= false
end

local function getTargetDebuffSpells()
	local settings = getFrameSettings("targetDebuffs")
	if not settings then
		return {}
	end

	if not settings.enabled then
		return {}
	end

	local targetExists = unitExists("target")
	local targetHostile = unitIsHostile("target")
	local targetDead = unitIsDead("target")
	if not targetExists or not targetHostile or targetDead then
		return {}
	end

	local classFile = getPlayerClass()
	local spells = targetDebuffsByClass[classFile] or {}
	if #spells == 0 then
		return {}
	end

	local missing = {}
	for index = 1, #spells do
		local spell = spells[index]
		if spellEnabled(settings, spell.key) and requirementMet(spell.requires) then
			local aura = findAura("target", spell.spell, "HARMFUL")
			if not aura then
				missing[#missing + 1] = spell
			end
		end
	end

	return missing
end

local function getBestShout()
	local settings = getFrameSettings("shouts")
	if not settings or not settings.enabled or getPlayerClass() ~= "WARRIOR" then
		return nil, nil
	end

	local warningSeconds = tonumber(settings.warningSeconds) or DEFAULT_WARNING_SECONDS
	local fallback
	for index = 1, #warriorShouts do
		local shout = warriorShouts[index]
		if spellEnabled(settings, shout.key) then
			fallback = fallback or shout
			local aura = findAura("player", shout.spell, "HELPFUL")
			if aura then
				local remaining
				if type(aura.expirationTime) == "number" and aura.expirationTime > 0 then
					remaining = aura.expirationTime - getNow()
				end
				if remaining and remaining <= warningSeconds then
					return shout, remaining
				end
				if aura.caster == "player" or reminders.lastOwnShoutSpell == shout.spell then
					return nil, remaining
				end
			end
		end
	end

	return fallback, nil
end

local function saveFramePosition(kind)
	local frameState = reminders.frames[kind]
	local settings = getFrameSettings(kind)
	if not frameState or not frameState.frame or not settings then
		return
	end

	local point, _, relativePoint, x, y = frameState.frame:GetPoint(1)
	settings.positionPreset = "custom"
	settings.point = point or "CENTER"
	settings.relativePoint = relativePoint or settings.point
	settings.x = x or 0
	settings.y = y or 0
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
end

local function applyFramePosition(kind)
	local frameState = reminders.frames[kind]
	local settings = getFrameSettings(kind)
	local overlays = getOverlaySettings()
	if not frameState or not frameState.frame or not settings or not overlays then
		return
	end

	frameState.frame:ClearAllPoints()
	frameState.frame:SetPoint(settings.point, UIParent, settings.relativePoint, settings.x, settings.y)
	frameState.frame:SetScale(overlays.scale)
	frameState.frame:SetAlpha(overlays.opacity)
end

local function applyFrameLock(kind)
	local frameState = reminders.frames[kind]
	local overlays = getOverlaySettings()
	if not frameState or not frameState.frame or not overlays then
		return
	end

	local unlocked = not overlays.locked
	frameState.frame:EnableMouse(unlocked)
	frameState.frame:SetMovable(unlocked)
	if unlocked then
		frameState.frame:RegisterForDrag("LeftButton")
	else
		frameState.frame:RegisterForDrag()
	end
	setRegionShown(frameState.background, unlocked)
	setRegionShown(frameState.handle, unlocked)
end

local function setVisibilityDriver(kind, active)
	local frameState = reminders.frames[kind]
	if not frameState then
		return
	end

	local overlays = getOverlaySettings()
	local unlocked = overlays and not overlays.locked
	local shown
	if kind == "shouts" then
		shown = active and isInCombat()
	elseif active then
		shown = true
	elseif unlocked then
		shown = true
	else
		shown = false
	end

	if shown then
		frameState.frame:Show()
	else
		frameState.frame:Hide()
	end
end

local function configureIcon(icon, spell)
	icon.texture:SetTexture(getSpellIcon(spell.spell, spell.icon))
	if icon.countdown then
		icon.countdown:SetText("")
	end
	icon:Show()
end

local function clearIcon(icon)
	icon.texture:SetTexture(nil)
	if icon.countdown then
		icon.countdown:SetText("")
	end
	icon:Hide()
end

local function prepareReminderIcons(kind, spells)
	local frameState = reminders.frames[kind]
	if not frameState then
		return false
	end

	spells = spells or {}
	for index = 1, frameState.buttonCount do
		local icon = frameState.items[index]
		local spell = spells[index]
		if spell then
			configureIcon(icon, spell)
		else
			clearIcon(icon)
		end
	end

	frameState.preparedCount = #spells
	setRegionShown(frameState.missingLabel, #spells > 0)
	setVisibilityDriver(kind, #spells > 0)
	return true
end

local function createReminderIcon(index, parent, countdown)
	local item = CreateFrame("Frame", parent:GetName() .. "Item" .. index, parent)
	item:SetSize(ICON_SIZE, ICON_SIZE)
	if index == 1 then
		item:SetPoint("LEFT", parent, "LEFT", 0, 0)
	else
		item:SetPoint("LEFT", parent.items[index - 1], "RIGHT", ICON_GAP, 0)
	end

	local texture = item:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	item.texture = texture

	local border = item:CreateTexture(nil, "OVERLAY")
	border:SetAllPoints()
	border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

	if countdown then
		local countdownText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		countdownText:SetPoint("BOTTOM", item, "BOTTOM", 0, 2)
		item.countdown = countdownText
	end

	item:Hide()
	return item
end

local function createReminderFrame(kind, buttonCount)
	local frame = CreateFrame("Frame", addonName .. kind .. "Reminder", UIParent)
	frame:SetSize(frameWidth(buttonCount), ICON_SIZE)
	frame:SetClampedToScreen(true)
	frame.items = {}

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	if background.SetColorTexture then
		background:SetColorTexture(0, 0, 0, 0.35)
	else
		background:SetTexture(0, 0, 0, 0.35)
	end

	local handle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	handle:SetPoint("BOTTOM", frame, "TOP", 0, 18)
	handle:SetText(kind == "targetDebuffs" and "Notatank target reminders" or "Notatank shout reminder")

	local missingLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	missingLabel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 3)
	missingLabel:SetText("Missing:")
	missingLabel:Hide()

	frame:SetScript("OnDragStart", function(self)
		if not isInCombat() then
			self:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		saveFramePosition(kind)
	end)

	local frameState = {
		frame = frame,
		background = background,
		handle = handle,
		missingLabel = missingLabel,
		items = frame.items,
		buttonCount = buttonCount,
		preparedCount = 0,
	}
	reminders.frames[kind] = frameState

	for index = 1, buttonCount do
		frame.items[index] = createReminderIcon(index, frame, kind == "shouts")
	end

	applyFramePosition(kind)
	applyFrameLock(kind)
	setVisibilityDriver(kind, false)
	return frameState
end

local function refreshTargetDebuffs()
	local missing = getTargetDebuffSpells()
	reminders.targetMissingCount = #missing
	return prepareReminderIcons("targetDebuffs", missing)
end

local function refreshPlayerShouts()
	local frameState = reminders.frames.shouts
	local shout, remaining = getBestShout()
	local active = shout ~= nil
	reminders.shoutActive = active

	if active then
		local prepared = prepareReminderIcons("shouts", { shout })
		if prepared and frameState and frameState.items[1] and remaining then
			frameState.items[1].countdown:SetText(("%d"):format(math.max(0, math.floor(remaining))))
		end
		return prepared
	end

	return prepareReminderIcons("shouts", {})
end

function addon:InitializeReminders()
	createReminderFrame("targetDebuffs", TARGET_BUTTON_COUNT)
	createReminderFrame("shouts", SHOUT_BUTTON_COUNT)

	self:RegisterEvent("PLAYER_TARGET_CHANGED", "RefreshTargetDebuffs")
	self:RegisterEvent("UNIT_AURA", "HandleReminderUnitAura")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "HandleReminderSpellcastSucceeded")
	self:ScheduleRepeatingTimer("RefreshPlayerBuffs", 1)

	self:RefreshTargetDebuffs()
	self:RefreshPlayerBuffs()
end

function addon:RefreshTargetDebuffs()
	return refreshTargetDebuffs()
end

function addon:RefreshPlayerBuffs()
	return refreshPlayerShouts()
end

function addon:HandleReminderUnitAura(event, unit)
	if unit == "target" then
		self:RefreshTargetDebuffs()
	elseif unit == "player" then
		self:RefreshPlayerBuffs()
	end
end

function addon:HandleReminderSpellcastSucceeded(event, unit, castGuid, spellId)
	if unit ~= "player" then
		return
	end

	local spellName = type(GetSpellInfo) == "function" and GetSpellInfo(spellId) or nil
	for index = 1, #warriorShouts do
		local shout = warriorShouts[index]
		if spellName == shout.spell or castGuid == shout.spell then
			reminders.lastOwnShoutSpell = shout.spell
			reminders.lastOwnShoutTime = getNow()
			self:RefreshPlayerBuffs()
			return
		end
	end
end

function addon:HandleRemindersRegenEnabled()
	self:RefreshTargetDebuffs()
	self:RefreshPlayerBuffs()
end

function addon:HandleRemindersRegenDisabled()
	if not isInCombat() then
		return
	end
	self:RefreshTargetDebuffs()
	self:RefreshPlayerBuffs()
end

function addon:SetRemindersLocked(locked)
	local overlays = getOverlaySettings()
	if not overlays then
		return false, "Saved settings are not ready."
	end

	overlays.locked = locked and true or false
	if not isInCombat() then
		applyFrameLock("targetDebuffs")
		applyFrameLock("shouts")
	end
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
	return true
end

function addon:SetReminderScale(scale)
	local overlays = getOverlaySettings()
	if not overlays then
		return false, "Saved settings are not ready."
	end

	scale = tonumber(scale) or 1
	if scale < 0.5 then
		scale = 0.5
	elseif scale > 2 then
		scale = 2
	end

	overlays.scale = scale
	if not isInCombat() then
		applyFramePosition("targetDebuffs")
		applyFramePosition("shouts")
	end
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
	return true
end

function addon:SetReminderOpacity(opacity)
	local overlays = getOverlaySettings()
	if not overlays then
		return false, "Saved settings are not ready."
	end

	opacity = tonumber(opacity) or 1
	if opacity < 0.2 then
		opacity = 0.2
	elseif opacity > 1 then
		opacity = 1
	end

	overlays.opacity = opacity
	if not isInCombat() then
		applyFramePosition("targetDebuffs")
		applyFramePosition("shouts")
	end
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
	return true
end

function addon:SetReminderPositionPreset(kind, preset)
	local settings = getFrameSettings(kind)
	if not settings then
		return false, "Saved settings are not ready."
	end

	if preset == "custom" then
		settings.positionPreset = "custom"
		if addon.NotifyOptionsChanged then
			addon:NotifyOptionsChanged()
		end
		return true
	end

	local presets = {
		targetDebuffs = {
			left = { "CENTER", "CENTER", -80, -140 },
			right = { "CENTER", "CENTER", 80, -140 },
			center = { "CENTER", "CENTER", 0, -140 },
		},
		shouts = {
			left = { "CENTER", "CENTER", -80, -190 },
			right = { "CENTER", "CENTER", 80, -190 },
			center = { "CENTER", "CENTER", 0, -190 },
		},
	}
	local value = (presets[kind] and presets[kind][preset]) or presets[kind].center
	settings.positionPreset = preset or "center"
	settings.point = value[1]
	settings.relativePoint = value[2]
	settings.x = value[3]
	settings.y = value[4]

	if not isInCombat() then
		applyFramePosition(kind)
	end
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
	return true
end

function addon:GetReminderState()
	local overlays = getOverlaySettings() or {}
	return {
		locked = overlays.locked,
		scale = overlays.scale,
		opacity = overlays.opacity,
		targetMissingCount = reminders.targetMissingCount,
		shoutActive = reminders.shoutActive,
	}
end
