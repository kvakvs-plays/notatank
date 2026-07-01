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
---@field spellId number?

---@class NotTargetAuras
---@field unit string
---@field name string?
---@field helpful table<NotAura>
---@field harmful table<NotAura>
local TargetAuras = {}
TargetAuras.__index = TargetAuras

local function trim(value)
	if type(value) ~= "string" then
		return nil
	end

	value = value:match("^%s*(.-)%s*$")
	return value ~= "" and value or nil
end

--- @return string?
local function resolveUnitName(unit)
	if type(UnitName) ~= "function" then
		return nil
	end

	local name, realm = UnitName(unit)
	name = trim(name)
	if not name then
		return nil
	end

	realm = trim(realm)
	if realm then
		return ("%s-%s"):format(name, realm)
	end

	return name
end

---@return NotAura?
local function normalizeAura(name, icon, count, duration, expirationTime, caster, filter, spellId)
	if type(name) ~= "string" or name == "" then
		return nil
	end

	spellId = tonumber(spellId)
	return {
		name = name,
		icon = icon,
		count = count,
		duration = duration,
		expirationTime = expirationTime,
		caster = caster,
		filter = filter,
		spellId = spellId,
	}
end

---@return NotAura?
local function normalizeAuraReturns(filter, ...)
	local name = ...
	if not name then
		return nil
	end

	local values = { ... }
	local spellId = tonumber(values[11]) or tonumber(values[10])
	local icon, count, duration, expirationTime, caster
	if tonumber(values[11]) or type(values[3]) == "string" then
		icon = values[3]
		count = values[4]
		duration = values[6]
		expirationTime = values[7]
		caster = values[8]
	else
		icon = values[2]
		count = values[3]
		duration = values[5]
		expirationTime = values[6]
		caster = values[7]
	end

	return normalizeAura(name, icon, count, duration, expirationTime, caster, filter, spellId)
end

local function readAuraWithUnitAura(unit, index, filter)
	if type(UnitAura) ~= "function" then
		return nil
	end

	return normalizeAuraReturns(filter, UnitAura(unit, index, filter))
end

local function readAura(unit, index, filter)
	local auraFunc = filter == "HELPFUL" and UnitBuff or UnitDebuff
	if type(auraFunc) == "function" then
		return normalizeAuraReturns(filter, auraFunc(unit, index))
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

function TargetAuras:Matches(aura, spell)
	if type(spell) == "number" then
		return aura and aura.spellId == spell
	elseif type(spell) == "string" then
		return aura and TargetAuras.NameMatches(aura.name, spell)
	end

	return false
end

function TargetAuras:Find(spell, filter)
	local auras = self:GetList(filter)
	if not auras then
		return nil
	end

	for index = 1, #auras do
		local aura = auras[index]
		if TargetAuras:Matches(aura, spell) then
			return aura
		end
	end

	return nil
end

function TargetAuras:FindAny(spells, filter)
	if type(spells) == "string" or type(spells) == "number" then
		return self:Find(spells, filter)
	end

	if type(spells) ~= "table" then
		return nil
	end

	for index = 1, #spells do
		local aura = self:Find(spells[index], filter)
		if aura then
			return aura
		end
	end

	return nil
end

function TargetAuras:FindSpell(spell, filter)
	if type(spell) == "string" or type(spell) == "number" then
		return self:Find(spell, filter)
	end

	if type(spell) ~= "table" then
		return nil
	end

	local aura = self:Find(spell.spell, filter)
	if aura then
		return aura
	end
	aura = self:Find(spell.spellId, filter)
	if aura then
		return aura
	end

	aura = self:FindAny(spell.spellIds, filter)
	if aura then
		return aura
	end

	return self:FindSpellAliases(spell, filter)
end

function TargetAuras:FindSpellAliases(spell, filter)
	if type(spell) ~= "table" then
		return nil
	end

	return self:FindAny(spell.auraSpells, filter)
		or self:Find(spell.auraSpellId, filter)
		or self:FindAny(spell.auraSpellIds, filter)
end

addon.TargetAuras = TargetAuras
