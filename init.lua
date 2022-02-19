local ADDON_NAME, ADDON = ...
local strformat = string.format
ADDON.a = _G['AstralEngine']

AAEvents = Event:New('AAEvents')

local RAID_TARGET_BIT = {}
RAID_TARGET_BIT[1] = 1
RAID_TARGET_BIT[2] = 2
RAID_TARGET_BIT[4] = 3
RAID_TARGET_BIT[8] = 4
RAID_TARGET_BIT[16] = 5
RAID_TARGET_BIT[32] = 6
RAID_TARGET_BIT[64] = 7
RAID_TARGET_BIT[128] = 8

ADDON.COLOURS = {}
ADDON.COLOURS.TARGET = 'FFFF0000'
ADDON.COLOURS.ADDON =  '008888FF'
ADDON.ADDON_NAME_COLOURED = WrapTextInColorCode('[AA]', ADDON.COLOURS.ADDON)

function AstralSendMessage(msg, channel)
	if not msg or type(msg) ~= 'string' then
		error('AstralSendMessage(msg, channel) msg expected, got ' .. type(msg))
	end

	local channel = channel or AstralAnalytics.options.general.reportChannel
	if channel == 'SMART' then
		channel= IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and 'INSTANCE_CHAT' or IsInRaid() and 'RAID' or 'PARTY'
	end
	if channel == 'console' then
		print(strformat('%s %s', ADDON.ADDON_NAME_COLOURED, msg))
	else
		SendChatMessage(msg, channel)
	end
end

function WrapNameInColorAndIcons(unitName, unitFlags, raidFlags)
	if not unitName or type(unitName) ~= 'string' then
		error('unitName expected, got ' .. type(unitName) ', ' .. tostring(unitName))
	end

	local bitRaid, raidIndex

	local icon = ''
	if raidFlags then
		bitRaid = bit.band(raidFlags, COMBATLOG_OBJECT_RAIDTARGET_MASK)	
		raidIndex = bitRaid and RAID_TARGET_BIT[bitRaid] or nil
	end

	if raidIndex then
		icon = _G['COMBATLOG_ICON_RAIDTARGET' .. raidIndex]
	end

	local class 
	if not unitName:find('<') then -- Pet unit, use owner's class color
		class = select(2, UnitClass(unitName))
	else
		class = select(2, UnitClass(unitName:match('<(.+)>')))
	end
	local nameColor
	if unitFlags and bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, unitFlags) > 4 then
		nameColor = ADDON.COLOURS.TARGET
	else
		nameColor = select(4, GetClassColor(class))
	end
	 --= hexColor or select(4, GetClassColor(class)) -- class hex color code
	if not nameColor then
		if AstralAnalytics.options.general.raidIcons and icon ~= '' then
			return strformat('%s%s%s', icon, unitName, icon)
		else
			return unitName
		end
	else
		if AstralAnalytics.options.general.raidIcons and icon ~= '' then
			return strformat('%s%s%s', icon, WrapTextInColorCode(unitName, nameColor), icon)
		else
			return WrapTextInColorCode(unitName, nameColor)
		end
	end
end

function ADDON:ColouredName(unit, class, hexColor)
	if not unit or type(unit) ~= 'string' then
		error('unit expected, got ' .. type(unit))
	end
	local class = class or select(2, UnitClass(unit))
	local nameColor = hexColor or select(4, GetClassColor(class)) -- Hex color code
	if not nameColor then
		return unit
	else
		return WrapTextInColorCode(unit, nameColor)
	end
end

local scanTool = CreateFrame( "GameTooltip", "AstralScanTool", nil, "GameTooltipTemplate" )
scanTool:SetOwner(WorldFrame, "ANCHOR_NONE" )
local scanText = _G["AstralScanToolTextLeft2"] -- This is the line with <[Player]'s Pet>

function ADDON:GetPetOwner(petName)
	if petName == 'Unknown' then return 'Unknown' end
	AstralScanTool:ClearLines()
	AstralScanTool:SetUnit(petName)
	local ownerText = scanText:GetText()
	if not ownerText then return 'Unknown' end
	local owner, _ = string.split("'",ownerText)
	return owner -- This is the pet's owner
end