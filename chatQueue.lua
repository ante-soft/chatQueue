local ADDON_NAME = "ChatQueue"

local AceGUI = LibStub("AceGUI-3.0")
chatQueue =
	LibStub("AceAddon-3.0"):NewAddon("chatQueue", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")
local ScrollingTable = LibStub("ScrollingTable")

local HealerRoleIcon = "|TInterface/Addons/chatQueue/media/Healer:20|t"
local DamageRoleIcon = "|TInterface/Addons/chatQueue/media/Damage:20|t"
local TankRoleIcon = "|TInterface/Addons/chatQueue/media/Tank:20|t"

local chatQueueOptions = {...}
chatQueueOptions.defaults = {
	global = {
		debug = false
	},
	char = {},
	profile = {
		minimap = {
			hide = false
		}
	}
}

local minimapIconLDB =
	LibStub("LibDataBroker-1.1"):NewDataObject(
	"chatQueueMinimapIcon",
	{
		type = "data source",
		text = ADDON_NAME,
		icon = "Interface/Icons/INV_Chest_Cloth_17",
		OnClick = function(self, button)
			if button == "LeftButton" then
				chatQueue:ToggleFrame()
				return
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(ADDON_NAME, 1, 1, 1)
		end
	}
)

local lfmTable = {}
local groupTable = {}

local chatQueueFrame = {}
local playerMessages = {}

local categories = {}
local leaderMessages = {}
local currentFilter = {}
currentFilter[HealerRoleIcon] = false
currentFilter[DamageRoleIcon] = false
currentFilter[TankRoleIcon] = false

local menuTable = {
	{text = "Player", isTitle = true, notCheckable = true},
	{
		text = "Invite",
		notCheckable = true,
		func = function()
			local table = chatQueueFrame.table
			if table.selected ~= nil then
				local player = unpack(table:GetRow(table.selected))
				InviteUnit(player)
			end
		end
	},
	{
		text = "Whisper",
		notCheckable = true,
		func = function()
			local table = chatQueueFrame.table
			if table.selected ~= nil then
				local message, player, class, dungeon, needs
				if chatQueueFrame.selectedTab == "LFG" then
					player, class, dungeon = unpack(table:GetRow(table.selected))
					message = "Hi, would you like to join for" .. dungeon .. "?"
				else
					player, dungeon, needs = unpack(table:GetRow(table.selected))
					message = "Hi, invite for " .. dungeon .. " please!"
				end
				SendChatMessage(message, "WHISPER", nil, player)
			end
		end
	},
	{
		text = "Who",
		notCheckable = true,
		func = function()
			local table = chatQueueFrame.table
			if table.selected ~= nil then
				local player, dungeon = unpack(table:GetRow(table.selected))
				C_FriendList.SendWho(player)
			end
		end
	}
}

function chatQueue:Debug(text)
	if self.db.global.debug == true then
		chatQueue:Print(text)
	end
end

function Wholefind(Search_string, Word)
	_, F_result = string.gsub(Search_string, "%f[%a]" .. Word .. "%f[%A]", "")
	return F_result
end

function round(num)
	under = math.floor(num)
	upper = math.floor(num) + 1
	underV = -(under - num)
	upperV = upper - num
	if (upperV > underV) then
		return under
	else
		return upper
	end
end

function split(pString, pPattern)
	local Table = {} -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = string.find(pString, fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(Table, cap)
		end
		last_end = e + 1
		s, e, cap = string.find(pString, fpat, last_end)
	end
	if last_end <= string.len(pString) then
		cap = string.sub(pString, last_end)
		table.insert(Table, cap)
	end
	return Table
end

function filterPunctuation(s)
	s = string.lower(s)
	local newString = ""
	for i = 1, string.len(s) do
		if string.find(string.sub(s, i, i), "%p") ~= nil then
			newString = newString .. " "
		elseif string.find(string.sub(s, i, i), "%d") ~= nil then
			--nothing needed here
		else
			newString = newString .. string.sub(s, i, i)
		end
	end
	return newString
end

function OnFilter()
	chatQueue:Debug("OnFilter - tab: " .. chatQueueFrame.selectedTab)

	local filter = function(self, rowdata)
		if chatQueueFrame.selectedTab == "LFG" then
			-- Filter by dungeon
			if currentFilter.dungeon == nil or rowdata[3] == currentFilter.dungeon then
				return true
			end
		end

		if chatQueueFrame.selectedTab == "LFM" then
			local needs = rowdata[3]
			local dungeon = rowdata[2]
			local isMatch = true

			if
				currentFilter[TankRoleIcon] == true or currentFilter[DamageRoleIcon] == true or
					currentFilter[HealerRoleIcon] == true
			 then
				isMatch = false

				if currentFilter[TankRoleIcon] == true and string.find(needs, TankRoleIcon) then
					isMatch = true
				end

				if currentFilter[DamageRoleIcon] == true and string.find(needs, DamageRoleIcon) then
					isMatch = true
				end

				if currentFilter[HealerRoleIcon] == true and string.find(needs, HealerRoleIcon) then
					isMatch = true
				end
			end

			if currentFilter.dungeon ~= nil then
				isMatch = false

				if dungeon == currentFilter.dungeon then
					isMatch = true
				end
			end

			return isMatch
		end
		return false
	end

	chatQueueFrame.table:SetFilter(filter)
end

function chatQueue:ToggleFrame()
	if chatQueueFrame.Shown then
		AceGUI:Release(chatQueueFrame)
		chatQueueFrame.Shown = false
		return
	end

	chatQueueFrame = AceGUI:Create("Frame")
	chatQueueFrame:SetCallback(
		"OnClose",
		function(widget)
			AceGUI:Release(widget)
			chatQueueFrame.Shown = false
		end
	)
	chatQueueFrame:SetTitle(ADDON_NAME)
	chatQueueFrame:SetHeight(650)
	chatQueueFrame:SetLayout("List")

	local tabGroup = AceGUI:Create("TabGroup")
	tabGroup:SetTabs({{text = "Looking for Group", value = "LFG"}, {text = "Looking for more", value = "LFM"}})
	tabGroup:SetFullHeight(true)
	tabGroup:SetFullWidth(true)
	tabGroup:SetHeight(390)
	tabGroup:SetLayout("Fill")
	tabGroup:SetCallback("OnGroupSelected", SelectGroup)
	tabGroup:SelectTab("LFG")

	-- local order = {}
	-- order[0] = rfc

	local dropdownGroup = AceGUI:Create("Dropdown")
	dropdownGroup:SetList(categories["Dungeons"])
	dropdownGroup:SetLabel("Dungeon")
	-- if chatQueueFrame.filter then
	-- 	print(chatQueueFrame.filter.key)
	-- 	dropdownGroup:SetValue("RFK")
	-- end
	dropdownGroup:SetCallback(
		"OnValueChanged",
		function(key)
			currentFilter.dungeon = key.value
			OnFilter()
		end
	)

	local clearButton = AceGUI:Create("Button")
	clearButton:SetText("Clear")
	clearButton:SetCallback(
		"OnClick",
		function(widget)
			if chatQueueFrame.selectedTab == "LFG" then
				wipe(groupTable)
				tabGroup.table:SetData(groupTable, true)
			end

			if chatQueueFrame.selectedTab == "LFM" then
				wipe(lfmTable)
				tabGroup.table:SetData(lfmTable, true)
			end
		end
	)

	local filterGroup = AceGUI:Create("InlineGroup")
	filterGroup:SetTitle("Filter")
	filterGroup:SetLayout("Flow")
	filterGroup:SetFullWidth(true)
	filterGroup:AddChildren(
		dropdownGroup,
		CreateRoleButton(TankRoleIcon),
		CreateRoleButton(HealerRoleIcon),
		CreateRoleButton(DamageRoleIcon)
	)

	chatQueueFrame:AddChildren(filterGroup, tabGroup, clearButton)

	chatQueueFrame.menu = CreateFrame("Frame", ADDON_NAME .. "MenuFrame", UIParent, "UIDropDownMenuTemplate")
	chatQueueFrame.Shown = true
end

function CreateRoleButton(role)
	local roleButton = AceGUI:Create("CheckBox")
	roleButton:SetLabel(role)
	roleButton:SetValue(false)
	roleButton:SetCallback(
		"OnValueChanged",
		function(current)
			currentFilter[role] = roleButton:GetValue()
			OnFilter()
		end
	)

	return roleButton
end

function DrawLFG(container)
	local cols = {}
	cols[1] = {
		["name"] = "Player",
		["width"] = 150,
		["align"] = "LEFT",
		["color"] = function(data, cols, realrow, column, table)
			if data[realrow] ~= nil then
				local player, class, dungeon = unpack(data[realrow])
				return getClassColor(class)
			end

			return {
				["r"] = 1.0,
				["g"] = 1.0,
				["b"] = 1.0,
				["a"] = 1.0
			}
		end,
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["defaultsort"] = "dsc",
		["sortnext"] = 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil
	}
	cols[2] = {
		["name"] = "Class",
		["width"] = 150,
		["align"] = "LEFT",
		["color"] = {
			["r"] = 1.0,
			["g"] = 1.0,
			["b"] = 1.0,
			["a"] = 1.0
		},
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["defaultsort"] = "dsc",
		["sortnext"] = 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil
	}
	cols[3] = {
		["name"] = "Dungeon",
		["width"] = 250,
		["align"] = "LEFT",
		["color"] = {
			["r"] = 1.0,
			["g"] = 1.0,
			["b"] = 1.0,
			["a"] = 1.0
		},
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["defaultsort"] = "dsc",
		["sortnext"] = 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil
	}

	local table = ScrollingTable:CreateST(cols, 15, 20, nil, container.frame)
	table:RegisterEvents(
		{
			["OnEnter"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
				if data[realrow] ~= nil then
					local player, class, dungeon = unpack(data[realrow])
					playerQueueToolTip:SetOwner(cellFrame, "ANCHOR_CURSOR")
					playerQueueToolTip:AddLine(playerMessages[player])
					playerQueueToolTip:Show()
				end

				return true
			end,
			["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
				if data[realrow] ~= nil and button == "RightButton" then
					EasyMenu(menuTable, chatQueueFrame.menu, "cursor", 0, 0, "MENU")
				end
				return table.selected == realrow
			end,
			["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
				playerQueueToolTip:Hide()
				return true
			end
		}
	)
	table:EnableSelection(true)
	table:SetData(groupTable, true)

	table:Show()
	return table
end

function DrawLFM(container)
	local cols = {}
	cols[1] = {
		["name"] = "Leader",
		["width"] = 150,
		["align"] = "LEFT",
		["color"] = function(data, cols, realrow, column, table)
			if data[realrow] ~= nil then
				local leader, dungeon, needs, class = unpack(data[realrow])
				return getClassColor(class)
			end

			return {
				["r"] = 1.0,
				["g"] = 1.0,
				["b"] = 1.0,
				["a"] = 1.0
			}
		end,
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["defaultsort"] = "dsc",
		["sortnext"] = 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil
	}
	cols[2] = {
		["name"] = "Dungeon",
		["width"] = 150,
		["align"] = "LEFT",
		["color"] = function(data, cols, realrow, column, table)
			if data[realrow] ~= nil then
				local leader, dungeon, needs, class = unpack(data[realrow])
				return getDifficultyColor(getglobal("MINLVLS")[dungeon], UnitLevel("player"))
			end
			return {
				["r"] = 1.0,
				["g"] = 1.0,
				["b"] = 1.0,
				["a"] = 1.0
			}
		end,
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["defaultsort"] = "dsc",
		["sortnext"] = 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil
	}
	cols[3] = {
		["name"] = "Needs",
		["width"] = 250,
		["align"] = "LEFT",
		["color"] = {
			["r"] = 1.0,
			["g"] = 1.0,
			["b"] = 1.0,
			["a"] = 1.0
		},
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["defaultsort"] = "dsc",
		["sortnext"] = 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil
	}

	local table = ScrollingTable:CreateST(cols, 15, 20, nil, container.frame)
	table:RegisterEvents(
		{
			["OnEnter"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
				if data[realrow] ~= nil then
					local leader, dungeon, needs, class = unpack(data[realrow])
					playerQueueToolTip:SetOwner(cellFrame, "ANCHOR_CURSOR")
					playerQueueToolTip:AddLine(leaderMessages[leader])
					playerQueueToolTip:Show()
				end
				return true
			end,
			["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, button, ...)
				if data[realrow] ~= nil and button == "RightButton" then
					EasyMenu(menuTable, chatQueueFrame.menu, "cursor", 0, 0, "MENU")
				end
				return table.selected == realrow
			end,
			["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
				playerQueueToolTip:Hide()
				return true
			end
		}
	)
	table:EnableSelection(true)
	table:SetData(lfmTable, true)

	table:Show()
	return table
end

-- Callback function for OnGroupSelected
function SelectGroup(container, event, group)
	container:ReleaseChildren()
	chatQueueFrame.selectedTab = group

	if chatQueueFrame.table then
		chatQueueFrame.table:Hide()
	end

	if group == "LFG" then
		chatQueueFrame.table = DrawLFG(container)
	elseif group == "LFM" then
		chatQueueFrame.table = DrawLFM(container)
	end

	OnFilter()
end

function chatQueue:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("chatQueueConfig", chatQueueOptions.defaults, true)

	self.profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, self.profileOptions)
	self.profilesFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "ChatQueue")

	-- Creating the minimap config icon
	chatQueue.minimapConfigIcon = LibStub("LibDBIcon-1.0")
	chatQueue.minimapConfigIcon:Register("chatQueueMinimapIcon", minimapIconLDB, self.db.profile.minimap)

	-- categories["Raids"] = {
	-- 	ubrs = "Upper Blackrock",
	-- 	ony = "Onyxia's Lair",
	-- 	zg = "Zul'Gurub",
	-- 	mc = "Molten Core",
	-- 	ruins = "Ruins of Ahn'Qiraj",
	-- 	bwl = "Blackwing Lair",
	-- 	temple = "Temple of Ahn'Qiraj",
	-- 	naxx = "Naxxramas"
	-- }
	categories["Dungeons"] = {
		rfc = "Ragefire Chasm",
		dead = "The Deadmines",
		wc = "Wailing Caverns",
		sfk = "Shadowfang Keep",
		stock = "The Stockade",
		bfd = "Blackfathom Deeps",
		gnomer = "Gnomeregan",
		rfk = "Razorfen Kraul",
		graveyard = "Scarlet Monastery - Graveyard",
		library = "Scarlet Monastery - Library",
		armory = "Scarlet Monastery - Armory",
		cathedral = "Scarlet Monastery - Cathedral",
		rfd = "Razorfen Downs",
		ulda = "Uldaman",
		zf = "Zul'Farrak",
		mara = "Maraudon",
		st = "The Sunken Temple",
		brd = "Blackrock Depths",
		lbrs = "Lower Blackrock",
		dm = "Dire Maul",
		strat = "Stratholme",
		scholo = "Scholomance",
		ubrs = "Upper Blackrock",
		ony = "Onyxia's Lair",
		zg = "Zul'Gurub",
		mc = "Molten Core",
		ruins = "Ruins of Ahn'Qiraj",
		bwl = "Blackwing Lair",
		temple = "Temple of Ahn'Qiraj",
		naxx = "Naxxramas"
	}

	chatQueue:RegisterEvent("CHAT_MSG_CHANNEL", OnChatMessage)

	chatQueue:Print("Initialized!")
end

function chatQueue:refreshTable(table, type)
	chatQueue:Debug("Refresh table " .. type)

	if chatQueueFrame.Shown and chatQueueFrame.selectedTab == type then
		chatQueueFrame.table:SetData(table, true)
	end
end

function chatQueue:CheckOldEntries()
	local currentTime = GetTime()
	for i, v in ipairs(lfmTable) do
		local dTime = difftime(currentTime, v.time)
		if dTime > 60 then
			tremove(lfmTable, i)
			chatQueue:Debug("Removed player " .. v[1])
			chatQueue:refreshTable(lfmTable, "LFM")
		end
	end

	for i, v in ipairs(groupTable) do
		local dTime = difftime(currentTime, v.time)
		if dTime > 60 then
			tremove(groupTable, i)
			chatQueue:Debug("Removed group " .. v[1])
			chatQueue:refreshTable(groupTable, "LFG")
		end
	end
end

function chatQueue:OnEnable()
	self.timer = self:ScheduleRepeatingTimer("CheckOldEntries", 30)

	CreateFrame("GameTooltip", "playerQueueToolTip", nil, "GameTooltipTemplate") -- Tooltip name cannot be nil
end

function chatQueue:OnDisable()
	self:CancelTimer(self.timer)
end

function getDifficultyColor(levelKey, playerLevel)
	local color = {}
	if (levelKey - playerLevel) >= 5 then
		color = {r = 1, g = 0, b = 0, a = 1}
	elseif (levelKey - playerLevel) <= 4 and (levelKey - playerLevel) >= 3 then
		color = {r = 1, g = 0.5, b = 0, a = 1}
	elseif (playerLevel - levelKey) <= 4 and (playerLevel - levelKey) >= 3 then
		color = {r = 0, g = 1, b = 0, a = 1}
	elseif (playerLevel - levelKey) > 4 then
		color = {r = 0.5, g = 0.5, b = 0.5, a = 1}
	else
		color = {r = 1, g = 1, b = 0, a = 1}
	end
	return color
end

function getClassColor(class)
	local classColor = {}
	classColor["DRUID"] = {r = 1, g = 0.49, b = 0.04, a = 1.0}
	classColor["HUNTER"] = {r = 0.67, g = 0.83, b = 0.45, a = 1.0}
	classColor["MAGE"] = {r = 0.41, g = 0.80, b = 0.94, a = 1.0}
	classColor["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73, a = 1.0}
	classColor["PRIEST"] = {r = 1, g = 1, b = 1, 1}
	classColor["ROGUE"] = {r = 1, g = 0.96, b = 0.41, a = 1.0}
	classColor["SHAMAN"] = {r = 0, g = 0.44, b = 0.87, a = 1.0}
	classColor["WARLOCK"] = {r = 0.58, g = 0.51, b = 0.79, a = 1.0}
	classColor["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43, a = 1.0}
	for k, v in pairs(classColor) do
		if k == class then
			return v
		end
	end
end

function hasGroup(table, item)
	local index = 1
	while table[index] do
		if (item.key == table[index].key) then
			return index
		end
		index = index + 1
	end
	return nil
end

function chatQueue:addToGroup(dungeon, type, player, playerClass, neededRoles)
	local entry = {}
	local index = nil
	if type == "LFG" then
		entry = {key = player, player, playerClass, dungeon, time = GetTime()}
		index = hasGroup(groupTable, entry)

		if index == nil then
			tinsert(groupTable, entry)
			chatQueue:refreshTable(groupTable, type)
		else
			groupTable[index].time = GetTime()
		end
	elseif type == "LFM" then
		entry = {key = player, player, dungeon, neededRoles, playerClass, time = GetTime()}
		index = hasGroup(lfmTable, entry)

		if index == nil then
			tinsert(lfmTable, entry)
			chatQueue:refreshTable(lfmTable, type)
		else
			lfmTable[index].time = GetTime()
		end
	end
end

function OnChatMessage(
	event,
	text,
	playerFullName,
	languageName,
	channelName,
	playerName2,
	specialFlags,
	zoneChannelID,
	channelIndex,
	channelBaseName,
	unused,
	lineID,
	guid)
	local puncString = filterPunctuation(text)
	local playerName, server = strsplit("-", playerFullName, 2)

	local healerRole = ""
	local damageRole = ""
	local tankRole = ""
	local groupFound = false

	for kLfm, vLfm in pairs(getglobal("LFMARGS")) do
		if Wholefind(puncString, vLfm) > 0 then
			for kCat, kVal in pairs(getglobal("CATARGS")) do
				for kkCat, kkVal in pairs(kVal) do
					if Wholefind(puncString, kkVal) > 0 then
						for kHeal, vHeal in pairs(getglobal("ROLEARGS")["Healer"]) do
							if Wholefind(puncString, vHeal) > 0 then
								healerRole = HealerRoleIcon
							end
						end
						for kDps, vDps in pairs(getglobal("ROLEARGS")["Damage"]) do
							if Wholefind(puncString, vDps) > 0 then
								damageRole = DamageRoleIcon
							end
						end
						for kTank, vTank in pairs(getglobal("ROLEARGS")["Tank"]) do
							if Wholefind(puncString, vTank) > 0 then
								tankRole = TankRoleIcon
							end
						end
						if healerRole == "" and tankRole == "" and damageRole == "" then
							healerRole = HealerRoleIcon
							damageRole = DamageRoleIcon
							tankRole = TankRoleIcon
						end
						local strippedStr = ""
						for i = 1, string.len(text) do
							local add = true
							if string.sub(text, i, i) == ":" then
								add = false
							end
							if add then
								strippedStr = strippedStr .. string.sub(text, i, i)
							end
						end
						leaderMessages[playerName] = strippedStr

						local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(guid)
						chatQueue:addToGroup(kCat, "LFM", playerName, englishClass, healerRole .. damageRole .. tankRole)
						groupFound = true
						break
					end
				end
			end
		end
	end

	if groupFound then
		return
	end

	for kLfg, vLfg in pairs(getglobal("LFGARGS")) do
		if Wholefind(puncString, vLfg) > 0 then
			for kCat, kVal in pairs(getglobal("CATARGS")) do
				for kkCat, kkVal in pairs(kVal) do
					if Wholefind(puncString, kkVal) > 0 then
						local strippedStr = ""
						for i = 1, string.len(text) do
							local add = true
							if string.sub(text, i, i) == ":" then
								add = false
							end
							if add then
								strippedStr = strippedStr .. string.sub(text, i, i)
							end
						end
						playerMessages[playerName] = strippedStr

						local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(guid)
						chatQueue:addToGroup(kCat, "LFG", playerName, englishClass)
						groupFound = true
						break
					end
				end
			end
		end
	end

	if groupFound == false then
		chatQueue:Debug("No match " .. puncString)
	end
end
