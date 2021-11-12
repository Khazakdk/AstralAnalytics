local ADDON_NAME, ADDON = ...
local strformat = string.format

ADDON.SPELL_CATEGORIES = {}

function ADDON:LoadSpells()
	if (AstralAnalytics.spellIds == nil) then
		AstralAnalytics.spellIds = {}
	end
	LoadPresets()
	for key, value in pairs(AstralAnalytics.spellIds) do
		if key ~= nil then
			if key == 'Taunt' then
				for spellId, _ in pairs(value) do
					ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', spellId, 'Taunt', '<sourceName> taunted <destName> with <spell>')
				end
			elseif key == 'Bloodlust' then
				for spellId, _ in pairs(value) do
					ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', spellId, 'Bloodlust', '<sourceName> cast <spell>')
				end
			elseif key == 'Targeted Utility' then
				for spellId, _ in pairs(value) do
					ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', spellId, 'Targeted Utility', '<sourceName> cast <spell> on <destName>')
				end
			elseif key == 'Group Utility' then
				for spellId, _ in pairs(value) do
					ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', spellId, 'Group Utility', '<sourceName> cast <spell>')
				end
			else
				for spellId, _ in pairs(value) do
					ADDON:AddSpellToCategory(spellId, key)
				end
			end
		end
	end
end

function ADDON:AddSpellToCategory(spellID, spellCategory)
	if not spellID or type(spellID) ~= 'number' then
		error('ADDON:AddSpellToCategory(spellID, spellCategory) spellID, number expected got ' .. type(spellID))
	end
	if not spellCategory or type(spellCategory) ~= 'string' then
		error('ADDON:AddSpellToCategory(spellID, spellCategory) spellCategory, string expected got ' .. type(spellCategory))
	end
	if not self.SPELL_CATEGORIES[spellCategory] then
		self.SPELL_CATEGORIES[spellCategory] = {}
	end
	if self.SPELL_CATEGORIES[spellCategory][spellID] ~= nil then
		ADDON:Print('AstralAnalytics:AddSpellToCategory(spellID, spellCategory) spellId already exists ' .. type(spellID))
	end
	table.insert(self.SPELL_CATEGORIES[spellCategory], spellID)
	ADDON:Print(spellID)
	if (AstralAnalytics.spellIds[spellCategory] == nil) then
		AstralAnalytics.spellIds[spellCategory] = {}
	end
	AstralAnalytics.spellIds[spellCategory][spellID] = true
end

function ADDON:RemoveSpellFromCategory(spellID, spellCategory)
	if not spellID or type(spellID) ~= 'number' then
		error('ADDON:AddSpellToCategory(spellID, spellCategory) spellID, number expected got ' .. type(spellID))
	end
	if not spellCategory or type(spellCategory) ~= 'string' then
		error('ADDON:AddSpellToCategory(spellID, spellCategory) spellCategory, string expected got ' .. type(spellCategory))
	end
	if self.SPELL_CATEGORIES[spellCategory][spellID] ~= nil then
		ADDON:Print('AstralAnalytics:AddSpellToCategory(spellID, spellCategory) spellId already does not exist ' .. type(spellID))
	end
	AstralAnalytics.spellIds[spellCategory][spellID] = nil
end

function ADDON:RetrieveSpellCategorySpells(spellCategory)
	if not spellCategory or type(spellCategory) ~= 'string' then
		error('ADDON:RetrieveSpellCategorySpells(spellCategory) spellCategory, string expected got ' .. type(spellCategory))
	end
	
	return self.SPELL_CATEGORIES[spellCategory]
end

function ADDON:IsSpellInCategory(spellID, spellCategory)
	if not spellID or type(spellID) ~= 'number' then
		error('ADDON:IsSpellInCategory(spellID, spellCategory) spellID, number expected got ' .. type(spellID))
	end
	if not spellCategory or type(spellCategory) ~= 'string' then
		error('ADDON:IsSpellInCategory(spellID, spellCategory) spellCategory, string expected got ' .. type(spellCategory))
	end

	if self.SPELL_CATEGORIES[spellCategory] then
		for i = 1, #self.SPELL_CATEGORIES[spellCategory] do
			if self.SPELL_CATEGORIES[spellCategory][i] == spellID then
				return true
			end
		end
	end

	return false
end

function ADDON:AddSpellToSubEvent(subEvent, spellID, spellCategory, msgString)
	if not self[subEvent] then
		self[subEvent] = {}
	end

	if self[subEvent][spellID] then
		ADDON:Print('AstralAnalytics:AddSpellToSubEvent(subEvent, spellID, spellCategory, msgString) spellID already registered')
	end

	local string = msgString

	local ls = ''
	local commandList = ''
	for command in string:gmatch('<(%w+)>') do
		if command:find('Name') then
			local unitText = command:sub(1, command:find('Name')- 1)
			if unitText == 'dest' then
				commandList = strformat('%s, %s, %sFlags, %sRaidFlags', commandList, command, unitText, unitText)
			else
				commandList = strformat('%s, %s, %sRaidFlags', commandList, command, unitText)
			end
		else
			commandList = strformat('%s, %s', commandList, command)
		end
		ls = strformat('%s, %s', ls, command)
	end
	commandList = commandList:sub(commandList:find(',') + 1)

	local fstring = string:gsub('<(.-)>', '%%s')

	ls = ls:gsub('(%w+)', function(w)
		if w:find('Name') then
			local flagText = w:sub(1, w:find('Name')- 1) .. 'RaidFlags'
			if w:find('dest') then
				return [[WrapNameInColorAndIcons(]] .. w .. [[, destFlags, ]] .. flagText .. [[)]]
			else
				return [[WrapNameInColorAndIcons(]] .. w .. [[, nil, ]] .. flagText .. [[)]]
			end
			--local colourText = w:find('dest') and ADDON.COLOURS.TARGET or 'nil'
			--return [[WrapNameInColorAndIcons(]] .. w .. [[, destFlags, ]] .. flagText .. [[)]]
		else
			return w
		end

	end)

	local codeString = [[
	if not AstralAnalytics.options.combatEvents[']] .. spellCategory .. [['] then return end
	local sourceName, sourceRaidFlags, spell, destName, destFlags, destRaidFlags = ...
	AstralSendMessage(string.format(']] .. fstring .. [[' ]] .. ls .. [[), 'console')]]

	local func, cerr = loadstring(codeString)
	if cerr then
		error(cerr)
	end

	self[subEvent][spellID] = {textString = msgString, method = func}
	self:AddSpellToCategory(spellID, spellCategory)
end

function ADDON:IsSpellTracked(subEvent, spellID)
	if not subEvent or type(subEvent) ~= 'string' then
		error('ADDON:IsSpellTracked(subEvent, spellID) subEvent, string expected got ' .. type(subEvent))
	end
	if not spellID or type(spellID) ~= 'number' then
		error('ADDON:IsSpellTracked(subEvent, spellID) spellID, number expected got ' .. type(spellID))
	end
	if self[subEvent] and self[subEvent][spellID] then
		return true
	else
		return false
	end
end

function ADDON:GetSubEventMethod(subEvent, spellID)
	if not subEvent or type(subEvent) ~= 'string' then
		error('ADDON:GetSubEventMethod(subEvent, spellID) subEvent, string expected got ' .. type(subEvent))
	end
	if not spellID or type(spellID) ~= 'number' then
		error('ADDON:GetSubEventMethod(subEvent, spellID) spellID, string expected got ' .. type(spellID))
	end

	return self[subEvent][spellID].method
end

function LoadPresets()
	-- Heroism
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 32182, 'Bloodlust', '<sourceName> cast <spell>') -- Heroism
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 90355, 'Bloodlust', '<sourceName> cast <spell>') -- Ancient Hysteria
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 160452, 'Bloodlust', '<sourceName> cast <spell>') -- Netherwinds
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 264667, 'Bloodlust', '<sourceName> cast <spell>') -- Primal Rage
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 80353, 'Bloodlust', '<sourceName> cast <spell>') -- Timewarp
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 2825, 'Bloodlust', '<sourceName> cast <spell>') -- Bloodlust
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 178207, 'Bloodlust', '<sourceName> cast <spell>') -- Drums of fury
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 230935, 'Bloodlust', '<sourceName> cast <spell>') -- Drums of the Mountain

	-- Battle res
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 20484, 'Battle Res', '<sourceName> resurrected <destName> with <spell>') -- Rebirth
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 20707, 'Battle Res', '<sourceName> cast <spell> on <destName>') -- Soulstone
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 61999, 'Battle Res', '<sourceName> resurrected <destName> with <spell>') -- Raise Ally
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 207399, 'Battle Res', '<sourceName> cast <spell>') -- Ancestral Protection Totem

	-- Taunts
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 115546, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Provoke, Monk
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 355, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Taunt, Warrior
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 185245, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Torment, Demon Hunter
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 62124, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Hand of Reckoning, Paladin
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 6795, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Growl, Druid
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 49576, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Death Grip, Death Knight
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 56222, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Dark Command, Death Knight
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 2649, 'Taunt', '<sourceName> taunted <destName> with <spell>') -- Growl, Hunter Pet
	-- need to check provoke

	-- Targeted Utility Spells
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 29166, 'Targeted Utility', '<sourceName> cast <spell> on <destName>') -- Innervate, Druid
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 34477, 'Targeted Utility', '<sourceName> cast <spell> on <destName>') -- Misdirect, Hunter
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 73325, 'Targeted Utility', '<sourceName> cast <spell> on <destName>') -- Leap of Faith, Priest
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 1022, 'Targeted Utility', '<sourceName> cast <spell> on <destName>') -- Blessing of Protection, Paladin
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 57934, 'Targeted Utility', '<sourceName> cast <spell> on <destName>') -- Tricks of the Trade, Rogue

	-- Non-targeted Utility Spells
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 205636, 'Group Utility', '<sourceName> cast <spell>') -- Force of Nature, Druid
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 77761, 'Group Utility', '<sourceName> cast <spell>') -- Stampeding Roar, Druid
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 77764, 'Group Utility', '<sourceName> cast <spell>') -- Stampeding Roar, Druid
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 106898, 'Group Utility', '<sourceName> cast <spell>') -- Stampeding Roar, Druid
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 64901, 'Group Utility', '<sourceName> cast <spell>') -- Symbol of Hope, Priest
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 114018, 'Group Utility', '<sourceName> cast <spell>') -- Shroud of Concealment, Rogue
	ADDON:AddSpellToSubEvent('SPELL_CAST_SUCCESS', 192077, 'Group Utility', '<sourceName> cast <spell>') -- Wind Rush Totem, Shaman

	-- Defensive Dispells
	ADDON:AddSpellToCategory(527, 'Dispel') -- Purify, Priest
	ADDON:AddSpellToCategory(218164, 'Dispel') -- Detox, Monk
	ADDON:AddSpellToCategory(115450, 'Dispel') -- Detox, Monk
	ADDON:AddSpellToCategory(2908, 'Dispel') -- Soothe, Druid
	ADDON:AddSpellToCategory(88425, 'Dispel') -- Nature's Cure, Druid
	ADDON:AddSpellToCategory(213644, 'Dispel') -- Cleanse Toxins, Paladin
	ADDON:AddSpellToCategory(4987, 'Dispel') -- Cleanse, Paladin
	ADDON:AddSpellToCategory(475, 'Dispel') -- Remove Curse, Mage
	ADDON:AddSpellToCategory(77130, 'Dispel') -- Purify Spirit, Shaman
	ADDON:AddSpellToCategory(51886, 'Dispel') -- Cleanse Spirit, Shaman


	-- Offensive Dispells
	ADDON:AddSpellToCategory(528, 'Dispel') -- Dispel Magic, Priest
	ADDON:AddSpellToCategory(30449, 'Dispel') -- Spellsteal, Mage
	ADDON:AddSpellToCategory(264028, 'Dispel') -- Chi-Ji's Tranquility, Hunter Pet
	ADDON:AddSpellToCategory(278326, 'Dispel') -- Consume Magic, Demon Hunter
	ADDON:AddSpellToCategory(370, 'Dispel') -- Purge, Shaman


	-- Interrupts
	ADDON:AddSpellToCategory(1766, 'Interrupts') -- Kick, Rogue
	ADDON:AddSpellToCategory(106839, 'Interrupts') -- Skull Bash
	ADDON:AddSpellToCategory(97547, 'Interrupts') -- Solar Beam 
	ADDON:AddSpellToCategory(183752, 'Interrupts') -- Consume Magic
	ADDON:AddSpellToCategory(147362, 'Interrupts') -- Counter Shot
	ADDON:AddSpellToCategory(187707, 'Interrupts') -- Muzzle
	ADDON:AddSpellToCategory(2139, 'Interrupts') -- Counter Spell
	ADDON:AddSpellToCategory(116705, 'Interrupts') -- Spear Hand Strike
	ADDON:AddSpellToCategory(96231, 'Interrupts') -- Rebuke
	ADDON:AddSpellToCategory(15487, 'Interrupts') -- Silence
	ADDON:AddSpellToCategory(57994, 'Interrupts') -- Windshear
	ADDON:AddSpellToCategory(6552, 'Interrupts') -- Pummel
	ADDON:AddSpellToCategory(171140, 'Interrupts') -- Shadow Lock
	ADDON:AddSpellToCategory(171138, 'Interrupts') -- Shadow Lock
	ADDON:AddSpellToCategory(183752, 'Interrupts') -- Disrupt
	ADDON:AddSpellToCategory(347008, 'Interrupts') -- Axe Toss
	ADDON:AddSpellToCategory(47528, 'Interrupts') -- Mind Freeze
	ADDON:AddSpellToCategory(31935, 'Interrupts') -- Avenger's Shield
end
