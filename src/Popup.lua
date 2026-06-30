---@type string, NotAddon
local addonName, addon = ...

local BUTTON_COUNT = 8
local BUTTON_WIDTH = 150
local BUTTON_HEIGHT = 24
local BUTTON_GAP = 4

local popup = {
	frame = nil,
	background = nil,
	handle = nil,
	buttons = {},
	queued = false,
	settingsQueued = false,
	preparedCount = 0,
}

addon.POPUP_BUTTON_COUNT = BUTTON_COUNT

local function isInCombat()
	return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function getProfilePopup()
	local profile = addon:GetProfile()
	if not profile then
		return nil
	end

	profile.popup = profile.popup or {}
	local settings = profile.popup
	if settings.locked == nil then
		settings.locked = true
	end
	settings.point = settings.point or "CENTER"
	settings.relativePoint = settings.relativePoint or settings.point
	settings.x = settings.x or 0
	settings.y = settings.y or 0
	settings.scale = settings.scale or 1

	return settings
end

local function formatButtonText(candidate)
	if candidate.mark then
		return ("{rt%d} %s"):format(candidate.mark, candidate.name)
	end

	return candidate.name
end

local function formatMacroText(candidate)
	return ("/tar [nodead] %s\n/startattack"):format(candidate.name)
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

local function setFrameVisibilityDriver()
	if not popup.frame then
		return
	end

	local settings = getProfilePopup()
	local unlocked = settings and not settings.locked

	if type(RegisterStateDriver) == "function" then
		local driver
		if unlocked then
			driver = "[combat] show; show"
		elseif popup.preparedCount > 0 then
			driver = "[combat] show; hide"
		else
			driver = "hide"
		end
		RegisterStateDriver(popup.frame, "visibility", driver)
	elseif unlocked or (popup.preparedCount > 0 and isInCombat()) then
		popup.frame:Show()
	else
		popup.frame:Hide()
	end
end

local function savePosition()
	local settings = getProfilePopup()
	if not settings or not popup.frame then
		return
	end

	local point, _, relativePoint, x, y = popup.frame:GetPoint(1)
	settings.positionPreset = "custom"
	settings.point = point or "CENTER"
	settings.relativePoint = relativePoint or settings.point
	settings.x = x or 0
	settings.y = y or 0
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
end

local function applyDragLock()
	local settings = getProfilePopup()
	if not settings or not popup.frame then
		return
	end

	local unlocked = not settings.locked
	popup.frame:EnableMouse(unlocked)
	popup.frame:SetMovable(unlocked)
	if unlocked then
		popup.frame:RegisterForDrag("LeftButton")
	else
		popup.frame:RegisterForDrag()
	end
	setRegionShown(popup.background, unlocked)
	setRegionShown(popup.handle, unlocked)
	setFrameVisibilityDriver()
end

local function applyPosition()
	local settings = getProfilePopup()
	if not settings or not popup.frame then
		return
	end

	popup.frame:ClearAllPoints()
	popup.frame:SetPoint(settings.point, UIParent, settings.relativePoint, settings.x, settings.y)
	popup.frame:SetScale(settings.scale)
end

local function createButton(index)
	local button = CreateFrame("Button", addonName .. "PopupButton" .. index, popup.frame, "SecureActionButtonTemplate")
	button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	if index == 1 then
		button:SetPoint("TOPLEFT", popup.frame, "TOPLEFT", 0, 0)
	else
		button:SetPoint("TOPLEFT", popup.buttons[index - 1], "BOTTOMLEFT", 0, -BUTTON_GAP)
	end

	button:RegisterForClicks("AnyUp")
	button:SetAttribute("type", "macro")
	button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

	local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("LEFT", button, "LEFT", 6, 0)
	label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
	label:SetJustifyH("LEFT")
	button.label = label

	button:Hide()
	return button
end

function addon:InitializePopup()
	popup.frame = CreateFrame("Frame", addonName .. "Popup", UIParent, "SecureHandlerStateTemplate")
	popup.frame:SetSize(BUTTON_WIDTH, (BUTTON_HEIGHT * BUTTON_COUNT) + (BUTTON_GAP * (BUTTON_COUNT - 1)))
	popup.frame:SetClampedToScreen(true)
	popup.frame:Hide()

	popup.background = popup.frame:CreateTexture(nil, "BACKGROUND")
	popup.background:SetAllPoints()
	if popup.background.SetColorTexture then
		popup.background:SetColorTexture(0, 0, 0, 0.35)
	else
		popup.background:SetTexture(0, 0, 0, 0.35)
	end

	popup.handle = popup.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	popup.handle:SetPoint("BOTTOM", popup.frame, "TOP", 0, 4)
	popup.handle:SetText("Notatank target popup")

	popup.frame:SetScript("OnDragStart", function(frame)
		if not isInCombat() then
			frame:StartMoving()
		end
	end)
	popup.frame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		savePosition()
	end)

	for index = 1, BUTTON_COUNT do
		popup.buttons[index] = createButton(index)
	end

	applyPosition()
	applyDragLock()
	setFrameVisibilityDriver()

	self:RequestPopupUpdate("addon loaded")
end

function addon:RequestPopupUpdate(reason)
	if isInCombat() then
		popup.queued = true
		return false, "Popup update queued until combat ends."
	end

	return self:PreparePopupButtons(self.GetCapturedTargets and self:GetCapturedTargets() or {})
end

function addon:PreparePopupButtons(candidates)
	if isInCombat() then
		popup.queued = true
		return false, "Popup update queued until combat ends."
	end

	candidates = candidates or {}
	local preparedCount = 0

	for index = 1, BUTTON_COUNT do
		local button = popup.buttons[index]
		local candidate = candidates[index]
		if candidate and candidate.name then
			preparedCount = preparedCount + 1
			button:SetAttribute("type", "macro")
			button:SetAttribute("macrotext", formatMacroText(candidate))
			button.label:SetText(formatButtonText(candidate))
			button:Show()
		else
			button:SetAttribute("macrotext", nil)
			button.label:SetText("")
			button:Hide()
		end
	end

	popup.preparedCount = preparedCount
	setFrameVisibilityDriver()
	return true, preparedCount
end

function addon:HandlePopupRegenEnabled()
	if popup.settingsQueued then
		popup.settingsQueued = false
		applyPosition()
		applyDragLock()
	end
	if popup.queued then
		popup.queued = false
		self:PreparePopupButtons(self.GetCapturedTargets and self:GetCapturedTargets() or {})
	else
		setFrameVisibilityDriver()
	end
end

function addon:HandlePopupRegenDisabled()
	if type(RegisterStateDriver) ~= "function" then
		setFrameVisibilityDriver()
	end
end

function addon:SetPopupLocked(locked)
	local settings = getProfilePopup()
	if not settings then
		return false, "Saved settings are not ready."
	end

	settings.locked = locked and true or false
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
	if isInCombat() then
		popup.settingsQueued = true
		return true
	end

	applyDragLock()
	return true
end

function addon:SetPopupScale(scale)
	local settings = getProfilePopup()
	if not settings then
		return false, "Saved settings are not ready."
	end

	scale = tonumber(scale) or 1
	if scale < 0.6 then
		scale = 0.6
	elseif scale > 2 then
		scale = 2
	end

	settings.scale = scale
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
	if isInCombat() then
		popup.settingsQueued = true
		return true
	end

	applyPosition()
	return true
end

function addon:SetPopupPositionPreset(preset)
	local settings = getProfilePopup()
	if not settings then
		return false, "Saved settings are not ready."
	end

	local presets = {
		center = { "CENTER", "CENTER", 0, 0 },
		left = { "LEFT", "LEFT", 180, 0 },
		right = { "RIGHT", "RIGHT", -180, 0 },
		top = { "TOP", "TOP", 0, -180 },
		bottom = { "BOTTOM", "BOTTOM", 0, 180 },
	}
	if preset == "custom" then
		settings.positionPreset = "custom"
		if addon.NotifyOptionsChanged then
			addon:NotifyOptionsChanged()
		end
		return true
	end

	local value = presets[preset] or presets.center

	settings.positionPreset = preset or "center"
	settings.point = value[1]
	settings.relativePoint = value[2]
	settings.x = value[3]
	settings.y = value[4]
	if addon.NotifyOptionsChanged then
		addon:NotifyOptionsChanged()
	end
	if isInCombat() then
		popup.settingsQueued = true
		return true
	end

	applyPosition()
	return true
end

function addon:GetPopupState()
	local settings = getProfilePopup() or {}
	return {
		locked = settings.locked,
		scale = settings.scale,
		positionPreset = settings.positionPreset or "custom",
		preparedCount = popup.preparedCount,
		queued = popup.queued,
	}
end
