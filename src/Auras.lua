---@type string, NotAddon
local addonName, addon = ...

local MAX_AURAS = 40

---@class NotAura
---@field name string
---@field icon string?
---@field count number?
---@field duration number?
---@field expirationTime number?
---@field caster string?
---@field filter "HELPFUL"|"HARMFUL"

---@class NotTargetAuras
---@field unit string
---@field name string?
---@field helpful table<NotAura>
---@field harmful table<NotAura>
local TargetAuras = {}
TargetAuras.__index = TargetAuras

--- @return string?
local function resolveUnitName(unit)
	if type(UnitName) ~= "function" then
		return nil
	end

	local name = UnitName(unit)
	if type(name) == "string" and name ~= "" then
		return name
	end

	return nil
end

---@return NotAura?
local function normalizeAura(name, icon, count, duration, expirationTime, caster, filter)
	if type(name) ~= "string" or name == "" then
		return nil
	end

	return {
		name = name,
		icon = icon,
		count = count,
		duration = duration,
		expirationTime = expirationTime,
		caster = caster,
		filter = filter,
	}
end

local function readAuraWithUnitAura(unit, index, filter)
	if type(UnitAura) ~= "function" then
		return nil
	end

	local name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitAura(unit, index, filter)
	return normalizeAura(name, icon, count, duration, expirationTime, caster, filter)
end

local function readAura(unit, index, filter)
	local auraFunc = filter == "HELPFUL" and UnitBuff or UnitDebuff
	if type(auraFunc) == "function" then
		local name, rank, icon, count, debuffType, duration, expirationTime, caster = auraFunc(unit, index)
		return normalizeAura(name, icon, count, duration, expirationTime, caster, filter)
	end

	return readAuraWithUnitAura(unit, index, filter)
end

local function scanAuras(unit, filter)
	local auras = {}
	if type(unit) ~= "string" or unit == "" then
		return auras
	end

	for index = 1, MAX_AURAS do
		local aura = readAura(unit, index, filter)
		if not aura then
			break
		end

		auras[#auras + 1] = aura
	end

	return auras
end

local function normalizeFilter(filter)
	if filter == "HELPFUL" or filter == "helpful" then
		return "HELPFUL"
	elseif filter == "HARMFUL" or filter == "harmful" then
		return "HARMFUL"
	end

	return nil
end

function TargetAuras.NameMatches(actual, wanted)
	if type(actual) ~= "string" or type(wanted) ~= "string" then
		return false
	end

	local actualLower = actual:lower()
	local wantedLower = wanted:lower()
	return actualLower == wantedLower or actualLower:sub(1, #wantedLower) == wantedLower
end

function TargetAuras:New(unit)
	local targetAuras = {
		unit = unit,
		name = resolveUnitName(unit),
		helpful = scanAuras(unit, "HELPFUL"),
		harmful = scanAuras(unit, "HARMFUL"),
	}

	return setmetatable(targetAuras, self)
end

function TargetAuras:GetList(filter)
	filter = normalizeFilter(filter)
	if filter == "HELPFUL" then
		return self.helpful
	elseif filter == "HARMFUL" then
		return self.harmful
	end

	return nil
end

function TargetAuras:Find(spellName, filter)
	local auras = self:GetList(filter)
	if not auras then
		return nil
	end

	for index = 1, #auras do
		local aura = auras[index]
		if TargetAuras.NameMatches(aura.name, spellName) then
			return aura
		end
	end

	return nil
end

function TargetAuras:FindAny(spellNames, filter)
	if type(spellNames) == "string" then
		return self:Find(spellNames, filter)
	end

	if type(spellNames) ~= "table" then
		return nil
	end

	for index = 1, #spellNames do
		local aura = self:Find(spellNames[index], filter)
		if aura then
			return aura
		end
	end

	return nil
end

addon.TargetAuras = TargetAuras
