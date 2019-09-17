local ADDON_NAME = "ChatQueue"

local AceGUI = LibStub("AceGUI-3.0")
vQueue = LibStub("AceAddon-3.0"):NewAddon("vQueue", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceTimer-3.0")
local ScrollingTable = LibStub("ScrollingTable");

local HealerRoleIcon = "|TInterface/Addons/vQueue/media/Healer:20|t"
local DamageRoleIcon = "|TInterface/Addons/vQueue/media/Damage:20|t"
local TankRoleIcon = "|TInterface/Addons/vQueue/media/Tank:20|t"

local vQueueOptions = {...};
vQueueOptions.defaults = {
	global = {
		debug = false,
	},
	char = {		
	},
	profile = {
		minimap = {
			hide = false,
		},
	},
}

local minimapIconLDB = LibStub("LibDataBroker-1.1"):NewDataObject("vQueueMinimapIcon", {
    type = "data source",
    text = ADDON_NAME,
    icon = "Interface/Icons/INV_Chest_Cloth_17",

    OnClick = function (self, button)
        if button == "LeftButton" then
			vQueue:ToggleFrame();
            return;
        end
    end,
    OnTooltipShow = function (tooltip)
        tooltip:AddLine(ADDON_NAME, 1, 1, 1);
    end,
});

local lfmTable = {}
local groupTable = {}

local vQueueFrame = {}
local playerMessages = {}

local categories = {}
local leaderMessages = {}

function vQueue:Debug(text)
	if self.db.global.debug == true then
		vQueue:Print(text)	
	end
end

function Wholefind(Search_string, Word)
	_, F_result = string.gsub(Search_string, '%f[%a]'..Word..'%f[%A]',"")
	return F_result
end
   
function addToSet(set, key)
	   set[key] = true
end
   
function removeFromSet(set, key)
	   set[key] = nil
end
   
function setContains(set, key)
	   return set[key] ~= nil
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
	local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = string.find(pString, fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
		table.insert(Table,cap)
		end
		last_end = e+1
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

function OnFilter(key)

	if key == nil or key.value == nil then
		return
	end

	vQueue:Debug("OnFilter " .. key.value .. " - tab: " .. vQueueFrame.selectedTab)

	local filter = function(self, rowdata)

		if vQueueFrame.selectedTab == "LFG" then
			if rowdata[3] == key.value then		
				return true;
			end
		end

		if vQueueFrame.selectedTab == "LFM" then
			if rowdata[2] == key.value then		
				return true;
			end
		end 
		return false
	end

	vQueueFrame.filter = key
	vQueueFrame.table:SetFilter(filter)
end

function vQueue:ToggleFrame()

	if vQueueFrame.Shown then
		AceGUI:Release(vQueueFrame)
		vQueueFrame.Shown = false
		return
	end

	CreateFrame("GameTooltip", "playerQueueToolTip", nil, "GameTooltipTemplate"); -- Tooltip name cannot be nil

	vQueueFrame = AceGUI:Create("Frame")
	vQueueFrame:SetCallback("OnClose",
	function(widget) 
		AceGUI:Release(widget)
		vQueueFrame.Shown = false
	end)
	vQueueFrame:SetTitle(ADDON_NAME)
	vQueueFrame:SetHeight(650)
	vQueueFrame:SetLayout("List")

	local tabGroup = AceGUI:Create("TabGroup")
	tabGroup:SetTabs({{text="Looking for Group", value="LFG"}, {text="Looking for more", value="LFM"}})
	tabGroup:SetFullHeight(true)
	tabGroup:SetFullWidth(true)
	tabGroup:SetHeight(390)
	tabGroup:SetLayout("Fill")
    tabGroup:SetCallback("OnGroupSelected", SelectGroup)
	tabGroup:SelectTab("LFG")

	local dropdownGroup = AceGUI:Create("Dropdown")
	dropdownGroup:SetList(categories["Dungeons"])
	dropdownGroup:SetLabel("Dungeon")
	dropdownGroup:SetCallback("OnValueChanged", OnFilter)

	local clearButton = AceGUI:Create("Button")
	clearButton:SetText("Clear")
	clearButton:SetCallback("OnClick",
		function(widget) 

			if vQueueFrame.selectedTab == "LFG" then
				wipe(groupTable)
				tabGroup.table:SetData(groupTable, true)
			end

			if vQueueFrame.selectedTab == "LFM" then
				wipe(lfmTable)
				tabGroup.table:SetData(lfmTable, true)
			end
		end)

	local filterGroup = AceGUI:Create("InlineGroup")
	filterGroup:SetTitle("Filter")
	filterGroup:SetLayout("Flow")
	filterGroup:SetFullWidth(true)
	filterGroup:AddChildren(dropdownGroup, CreateRoleButton(TankRoleIcon), CreateRoleButton(HealerRoleIcon), CreateRoleButton(DamageRoleIcon))

	vQueueFrame:AddChildren(filterGroup, tabGroup, clearButton)
	vQueueFrame.Shown = true
end

function CreateRoleButton(role)
	local roleButton = AceGUI:Create("CheckBox")
	roleButton:SetLabel(role)
	roleButton:SetCallback("OnValueChanged",
		function(value) 

		end)

	return roleButton
end

function DrawLFG(container)
	local cols = {}
	cols[1] = {
		["name"] = "Player",
		["width"] = 150,
		["align"] = "LEFT",
		["color"] = function (data, cols, realrow, column, table)
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
		["sortnext"]= 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil,
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
		["sortnext"]= 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil,
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
		["sortnext"]= 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil,
	}

	local table = ScrollingTable:CreateST(cols, 15, 20, nil, container.frame);
	table:RegisterEvents({
		["OnEnter"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)

			if data[realrow] ~= nil then
				local player, class, dungeon = unpack(data[realrow])
				playerQueueToolTip:SetOwner(cellFrame, "ANCHOR_CURSOR");
				playerQueueToolTip:AddLine(playerMessages[player])
				playerQueueToolTip:Show()
			end
			
			return true;
		end,
		["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
			if data[realrow] ~= nil then
				local player, class, dungeon = unpack(data[realrow])
				vQueue:Debug("Invite " .. player)
				InviteByName(player);
			end
			return true;
		end,
		["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
			playerQueueToolTip:Hide()
			return true;
		end,
	})	
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
		["color"] = function (data, cols, realrow, column, table)
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
		["sortnext"]= 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil,
	}
	cols[2] = {
		["name"] = "Dungeon",
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
		["DoCellUpdate"] = nil,
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
		["sortnext"]= 4,
		["comparesort"] = nil,
		["DoCellUpdate"] = nil,
	}

	local table = ScrollingTable:CreateST(cols, 15, 20, nil, container.frame);
	table:RegisterEvents({
		["OnEnter"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)

			if data[realrow] ~= nil then
				
				local leader, dungeon, needs, class = unpack(data[realrow])
				playerQueueToolTip:SetOwner(cellFrame, "ANCHOR_CURSOR");
				playerQueueToolTip:AddLine(leaderMessages[leader])
				playerQueueToolTip:Show()
			end

			return true;
		end,
		["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
			if data[realrow] ~= nil then
				local leader, dungeon, needs, class = unpack(data[realrow])
				SendChatMessage("Hi, invite please!", "WHISPER", nil, leader);
			end
			return true;
		end,
		["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
			playerQueueToolTip:Hide()
			return true;
		end,
	})	
	table:EnableSelection(true)
	table:SetData(lfmTable, true)
	
	table:Show()
	return table
  end
  
  -- Callback function for OnGroupSelected
function SelectGroup(container, event, group)
	 container:ReleaseChildren()
	 vQueueFrame.selectedTab = group
	
	 if vQueueFrame.table then
		vQueueFrame.table:Hide()
	 end

	 if group == "LFG" then
		vQueueFrame.table = DrawLFG(container)	
	 elseif group == "LFM" then
		vQueueFrame.table = DrawLFM(container)
	 end

	 OnFilter(vQueueFrame.filter)
end

function vQueue:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("vQueueConfig", vQueueOptions.defaults, true)

	-- Creating the minimap config icon
	vQueue.minimapConfigIcon = LibStub("LibDBIcon-1.0");
	vQueue.minimapConfigIcon:Register("vQueueMinimapIcon", minimapIconLDB, self.db.profile.minimap);

	categories["Raids"] =
	{
		ubrs = "Upper Blackrock",
		ony = "Onyxia's Lair",
		zg = "Zul'Gurub",
		mc = "Molten Core",
		ruins = "Ruins of Ahn'Qiraj",
		bwl ="Blackwing Lair",
		temple = "Temple of Ahn'Qiraj",
		naxx = "Naxxramas"
	}
	categories["Dungeons"] = 
	{
		rfc = "Ragefire Chasm",
		dead ="The Deadmines",
		wc ="Wailing Caverns",
		sfk ="Shadowfang Keep",
		stock = "The Stockade",
		bfd = "Blackfathom Deeps",
		gnomer= "Gnomeregan",
		rfk ="Razorfen Kraul",
		graveyard = "Scarlet Monastery - Graveyard",
		library ="Scarlet Monastery - Library",
		armory = "Scarlet Monastery - Armory",
		cathedral = "Scarlet Monastery - Cathedral",
		rfd = "Razorfen Downs",
		ulda = "Uldaman",
		zf = "Zul'Farrak",
		mara = "Maraudon",
		st = "The Sunken Temple",
		brd = "Blackrock Depths",
		lbrs = "Lower Blackrock",
		dm ="Dire Maul",
		strat = "Stratholme",
		scholo = "Scholomance"	
	}

	-- vQueue:RegisterEvent("CHAT_MSG_SAY", OnChatMessage)
	vQueue:RegisterEvent("CHAT_MSG_CHANNEL", OnChatMessage)

	vQueue:Print("Initialized!")
end

function vQueue:refreshTable(table, type)

    vQueue:Debug("Refresh table " .. type)	
	
	if vQueueFrame.Shown and vQueueFrame.selectedTab == type then
		vQueueFrame.table:SetData(table, true)
	end
end

function vQueue:CheckOldEntries()
	local currentTime = GetTime()
	for i,v in ipairs(lfmTable) do 
	
		local dTime = difftime(currentTime, v.time)
		if dTime > 60 then
			 tremove(lfmTable, i)
			 vQueue:Debug("Removed player " .. v[1])
			 vQueue:refreshTable(lfmTable, "LFM")
		end
	end
	
	for i,v in ipairs(groupTable) do 
	
		local dTime = difftime(currentTime, v.time)
		if dTime > 60 then
			 tremove(groupTable, i)
			 vQueue:Debug("Removed group " .. v[1])
			 vQueue:refreshTable(groupTable, "LFG")
		end
    end
end

function vQueue:OnEnable()
	self.timer = self:ScheduleRepeatingTimer("CheckOldEntries", 30)
end

function vQueue:OnDisable()
	self:CancelTimer(self.timer)
end

-- return the first integer index holding the value
function AnIndexOf(t,val)
	local i = 0
    for k,v in pairs(t) do 
        if k == val then return i end
		if v ~= nil then i = i+1 end
    end
end

function getDifficultyColor(levelKey, playerLevel)
	local color = {}
	if (levelKey - playerLevel) >= 5 then
		color[1] = 1
		color[2] = 0
		color[3] = 0
	elseif  (levelKey - playerLevel) <= 4  and (levelKey - playerLevel) >= 3 then
		color[1] = 1
		color[2] = 0.5
		color[3] = 0
	elseif  (playerLevel - levelKey) <= 4  and (playerLevel - levelKey) >= 3 then
		color[1] = 0
		color[2] = 1
		color[3] = 0
	elseif  (playerLevel - levelKey) > 4 then
		color[1] = 0.5
		color[2] = 0.5
		color[3] = 0.5
	else
		color[1] = 1
		color[2] = 1
		color[3] = 0
	end
	return color
end

function getClassColor(class)
	local classColor = {}
	classColor["DRUID"] = { r = 1, g = 0.49, b = 0.04, a = 1.0}
	classColor["HUNTER"] = { r = 0.67,g = 0.83, b = 0.45, a = 1.0}
	classColor["MAGE"] = {r = 0.41, g = 0.80, b = 0.94, a = 1.0}
	classColor["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73, a =1.0}
	classColor["PRIEST"] = {r = 1, g = 1, b = 1, 1}
	classColor["ROGUE"] = {r = 1, g = 0.96, b = 0.41, a = 1.0}
	classColor["SHAMAN"] = {r = 0, g = 0.44, b = 0.87, a = 1.0}
	classColor["WARLOCK"] = {r = 0.58, g = 0.51, b = 0.79, a = 1.0}
	classColor["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43, a = 1.0}
	for k, v in pairs(classColor) do
		if k == class then return v end
	end
end

function hasGroup(table, item)
	local index = 1;
	while table[index] do
			if (item.key == table[index].key) then
				return index;
			end
			index = index + 1;
	end
	return nil;
end

function vQueue:addToGroup(dungeon, type, player, playerClass, neededRoles)

	local entry = {}
	local index = nil
	if type == "LFG" then	
		entry = { key = player, player, playerClass, dungeon, time = GetTime() }
		index = hasGroup(groupTable, entry)

		if index == nil then		
			tinsert(groupTable, entry)
		    vQueue:refreshTable(groupTable, type)
		else
			groupTable[index].time = GetTime()
		end
	elseif type == "LFM" then
		entry = { key = player, player, dungeon, neededRoles, playerClass, time = GetTime() }
		index = hasGroup(lfmTable, entry)

		if index == nil then	
			tinsert(lfmTable, entry)
			vQueue:refreshTable(lfmTable, type)
		else
			lfmTable[index].time = GetTime()
		end
	 end
end

function OnChatMessage(event, text, playerFullName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid)
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
						for i=1, string.len(text) do
							local add = true
							if string.sub(text, i, i) == ":" then
								add = false
							end
							if add then
								strippedStr = strippedStr .. string.sub(text, i, i)
							end
						end
						leaderMessages[playerName] = strippedStr	
						
						local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(guid);
						vQueue:addToGroup(kCat , "LFM",  playerName, englishClass, healerRole .. damageRole .. tankRole)
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
						for i=1, string.len(text) do
							local add = true
							if string.sub(text, i, i) == ":" then
								add = false
							end
							if add then
								strippedStr = strippedStr .. string.sub(text, i, i)
							end
						end
						playerMessages[playerName] = strippedStr	
						
						local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(guid);
						vQueue:addToGroup(kCat , "LFG",  playerName, englishClass)
						groupFound = true;	
						break
					end
				end
			end
		end
	end

	if groupFound == false then
		vQueue:Debug("No match " .. puncString)
    end
end