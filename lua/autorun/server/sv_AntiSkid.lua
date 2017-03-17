--------------------
// Made by Dev for Werwolf //
--------------------
local version = "v3.0"
--------------------
// Spooling net messages //
--------------------
util.AddNetworkString( "antiSkidConvarCheck2" )
util.AddNetworkString( "antiSkidConvarReturn" )
util.AddNetworkString( "antiSkidConCommandCheck" )
util.AddNetworkString( "antiSkidConCommandReturn" )
util.AddNetworkString( "antiSkidLuaFilesCheck" )
util.AddNetworkString( "antiSkidLuaFilesReturn" )
util.AddNetworkString( "antiSkidConCommandUpdate" )
util.AddNetworkString( "antiSkid_message" )
--------------------
// Config //
--------------------
local antiSkidEnabled = 1 -- Enabled?
local antiSkidAdminGroup = "trialmod" -- Lowest admin group to output to
local antiSkidOutput = 1 -- Output detections to staff?
local antiSkidDelay = 30 -- Time to wait until re-output of detection

local antiSkidConvarKick = 1 -- Kick for UNSYNCED Convars (RECOMMENDED)
local antiSkidConCommandKick = 1 -- Kick for concommand failure (RECOMMENDED)
local antiSkidLog = 1 -- Log every action/detection made by AntiSkid
--------------------
// Startup Checks //
--------------------
hook.Add("Initialize", "antiSkidBootup", function()
	if not file.IsDir("antiSkid", "DATA") then file.CreateDir("antiSkid", "DATA") end
	if not file.Exists("antiSkid/Log.txt", "DATA") then file.Write("antiSkid/Log.txt", "") end
	if not file.Exists("antiSkid/Whitelist.txt","DATA") then file.Write("antiSkid/Whitelist.txt") end
	if not file.Exists("antiSkid/Bulletin.txt", "DATA") then file.Write("antiSkid/Bulletin.txt") end
	Msg("AntiSkid loading version: " .. version .. "\n")
	Msg("Server Secure with AntiSkid\n")
end)
local playersForTimeout = {}
hook.Add("PlayerInitialSpawn", "antiSkidCollectPly", function(ply)
	table.insert(playersForTimeout,ply)
end)
hook.Add("PlayerDisconnected", "antiSkidCollectPlyRemove", function(ply)
	table.RemoveByValue(playersForTimeout,ply)
end)
--------------------
// Main code //
--------------------
-- Chat message
local function messClient(message,ply)
	net.Start("antiSkid_message")
		net.WriteString(message)
	net.Send(ply)
end
local playerMeta = FindMetaTable("Player")

function playerMeta:AntiSkidAdmin()
	return self:CheckGroup(antiSkidAdminGroup)
end

local function AntiSkidOutputAdmin(msg)
	if antiSkidOutput == 0 then return end
	for k,v in pairs(player.GetAll()) do
		if v:AntiSkidAdmin() then messClient(msg,v) end
	end
end

local loggedPlayers = {} -- Holds nil by default

local function AntiSkidLog(ply,reason,action)
	if antiSkidLog == 0 then return end
	local check = ply:SteamID() .. reason
	if table.HasValue(loggedPlayers,check) then return end
	table.insert(loggedPlayers,check)
	local timeStamp = os.time()
	local TimeStr = os.date( "%X - %d/%m/%Y" , Timestamp )
	local data = "[" .. TimeStr .. "]" .. "[" .. string.upper(action) .. "]" .. "[" .. ply:Name() .. "]" .. "[" .. ply:SteamID() .. "]" .. "[" .. ply:IPAddress() .. "] " .. reason .. "\r\n"
	file.Append("antiSkid/Log.txt", data)
	Msg("AntiSkid: Player [" .. ply:Name() .. "]" .. " was flagged for [" .. reason .. "]" .. " and has been [" .. action .. "]\n")
end

local function AntiSkidDetection(ply,reason,key)
	if key == 1 then
		if ply:GetNWBool("antiSkidConvarDetected") == true then return end
		ply:SetNWBool("antiSkidConvarDetected", true)
		if antiSkidConvarKick == 1 then
			AntiSkidLog(ply,"UNSYCNED ConVar (" .. reason .. ")", "KICKED")
			AntiSkidOutputAdmin("Player: " .. ply:Name() .. " has returned UNSYNCED ConVar (" .. reason .. ") [KICKED]")
			ply:Kick("[Anti-Skid]You have been dropped for: Cheating")
		else
			AntiSkidLog(ply,"UNSYCNED ConVar (" .. reason .. ")", "LOGGED")
			AntiSkidOutputAdmin("Player: " .. ply:Name() .. " has returned UNSYNCED ConVar (" .. reason .. ") [LOGGED]")
		end
		timer.Simple(antiSkidDelay, function()
			if not ply:IsPlayer() or not ply then return end
			ply:SetNWBool("antiSkidConvarDetected", false)
		end)
	elseif key == 2 then
		if ply:GetNWBool("antiSkidConCommandDetected") == true then return end
		ply:SetNWBool("antiSkidConCommandDetected", true)
		if antiSkidConCommandKick == 1 then
			AntiSkidLog(ply,"INVALID ConCommand(s) (" .. reason .. ")","KICKED")
			AntiSkidOutputAdmin("Player: " .. ply:Name() .. " has returned INVALID ConCommand(s) (" .. reason .. ") [KICKED]")
			ply:Kick("[Anti-Skid]You have been dropped for: Cheating")
		else
			AntiSkidLog(ply, "INVALID ConCommand(s) (" .. reason .. ")", "LOGGED")
			AntiSkidOutputAdmin("Player: " .. ply:Name() .. " has returned INVALID ConCommand(s) (" .. reason .. ") [LOGGED]")
		end
		timer.Simple(antiSkidDelay, function()
			if not ply:IsPlayer() or not ply then return end
			ply:SetNWBool("antiSkidConCommandDetected", false)
		end)
	end
end

local function AntiSkidConvarCheckSend()
	for k,v in pairs(player.GetAll()) do
		net.Start("antiSkidConvarCheck2")
		net.Send(v)
	end
end
timer.Create("antiSkidConvarCheckTimer", 15,0,AntiSkidConvarCheckSend)

net.Receive("antiSkidConvarReturn", function(l,ply)
	local c_convars = net.ReadTable()
	local s_convars = {
	GetConVar("sv_allowcslua"),
	GetConVar("sv_cheats"),
	GetConVar("host_timescale"),
	}
	for k,v in pairs(s_convars) do
		if v:GetString() ~= c_convars[k] then
			AntiSkidDetection(ply,v:GetString() .. " expected got " .. c_convars[k] .. " for " .. v:GetName(),1)
		end
	end
end)

-- ConCommand whitelist creation

local function updateCons()
	net.Start("antiSkidConCommandUpdate")
	net.Broadcast()
end

local function checkTables(haystack,needle)
	local bad = {}
	for k,v in pairs(needle) do
		if !table.HasValue(haystack, v) then
			table.insert(bad, v)
		end
	end
	if #bad > 0 then
		return {true, bad}
	else
		return {false, nil}
	end
end

local function safeaddTable(master,add)
	return table.HasValue(master, add)
end

local function checkBadCMDS(ply)
	local bad = {}
	for k,v in pairs(player.GetAll()) do
		if (!v:IsPlayer()) or (!v.ASccamount) then continue end
		local o = checkTables(v.ASccvalues, ply.ASccvalues)
		if o[1] == false then continue end
		if !safeaddTable(bad,o[2]) then table.Merge(bad, o[2]) end
	end
	if #bad > 0 then
		return {true, bad}
	else
		return {false, nil}
	end
end

local function scancom(ply,key)
	if key == 1 then
		AntiSkidOutputAdmin("Player " .. ply:Name() .. " has returning an invalid amount of console commands, scanning for differences..")
	else
		AntiSkidOutputAdmin("Player " .. ply:Name() .. " is being scanned for differences in console commands")
	end
	ply:SetNWBool("ASconcommandinfo", false)
	updateCons()
	timer.Simple(3, function()
		if !ply or !ply:IsPlayer() then return end
		if (!ply.ASccvalues) or (#ply.ASccvalues < 1) then
			AntiSkidOutputAdmin("Scanning has been halted: Unable to retrieve information from client")
			return
		end
		local o = checkBadCMDS(ply)
		if o[1] == false then
			AntiSkidOutputAdmin("Scanning has completed: Client has no different console commands")
		else
			local string = table.ToString(o[2])
			--AntiSkidOutputAdmin("Scanning has completed: Client has returned differences in console commands (" .. string.SetChar(string, string.len(string)-1, "") .. ")")
			AntiSkidDetection(ply, string.SetChar(string, string.len(string)-1, ""), 2)
		end
		ply:SetNWBool("ASconcommandinfo", true)
	end)
end

timer.Create("antiSkidConCommandCheckTimer", 20, 0, function()
	updateCons()
end)

net.Receive("antiSkidConCommandUpdate", function(l,ply)
	local c_cmds = net.ReadTable()

	if ply:GetNWBool("ASconcommandinfo", false) == true then
		if #c_cmds > ply.ASccamount then
			scancom(ply,1)
		end
	end

	ply.ASccamount = #c_cmds
	ply.ASccvalues = c_cmds
	ply:SetNWBool("ASconcommandinfo", true)
end)

hook.Add("PlayerInitialSpawn", "antiskidConAmount", function(ply)
	timer.Simple(5, function()
		net.Start("antiSkidConCommandUpdate")
		net.Send(ply)
	end)
end)

-- End

hook.Add("PlayerInitialSpawn", "antiSkidLuaCheck", function(ply)
	net.Start("antiSkidLuaFilesCheck")
	net.Send(ply)
end)

local defaultLuaWhitelist = {
"sv_apanti.lua","aocroc.lua","aocroc_npc.lua","base_npcs.lua","base_vehicles.lua","clonetrooper_playermodels.lua","developer_functions.lua",
"game_hl2.lua","hazmatconscripts_npcs.lua","hazmatconscripts_playermodel.lua","hazmatconscripts_random.lua","menubar.lua","properties.lua","utilities_menu.lua","derma.lua","derma_animation.lua",
"derma_example.lua","derma_gwen.lua","derma_menus.lua","derma_utils.lua","init.lua","drive_base.lua","drive_noclip.lua","drive_sandbox.lua","sent_ball.lua","widget_arrow.lua","widget_axis.lua",
"widget_base.lua","widget_bones.lua","widget_disc.lua","gmsave.lua","init_menu.lua","menu.lua","util.lua","vgui_base.lua","player_color.lua","player_weapon_color.lua","sky_paint.lua",
"background.lua","demo_to_video.lua","errors.lua","getmaps.lua","loading.lua","mainmenu.lua","menu_addon.lua","menu_demo.lua","menu_dupe.lua","menu_save.lua","motionsensor.lua",
"progressbar.lua","video.lua","bloom.lua","bokeh_dof.lua","color_modify.lua","dof.lua","frame_blend.lua","motion_blur.lua","overlay.lua","sharpen.lua","sobel.lua","stereoscopy.lua",
"sunbeams.lua","super_dof.lua","texturize.lua","toytown.lua","default.lua","red&black_skin.lua","contextbase.lua","dadjustablemodelpanel.lua","dalphabar.lua","dbinder.lua",
"dbubblecontainer.lua","dbutton.lua","dcategorycollapse.lua","dcategorylist.lua","dcheckbox.lua","dcolorbutton.lua","dcolorcombo.lua","dcolorcube.lua","dcolormixer.lua","dcolorpalette.lua",
"dcolumnsheet.lua","dcombobox.lua","ddragbase.lua","ddrawer.lua","dentityproperties.lua","dexpandbutton.lua","dfilebrowser.lua","dform.lua","dframe.lua","dgrid.lua","dhorizontaldivider.lua",
"dhorizontalscroller.lua","dhtml.lua","dhtmlcontrols.lua","diconbrowser.lua","diconlayout.lua","dimage.lua","dimagebutton.lua","dkillicon.lua","dlabel.lua","dlabeleditable.lua","dlabelurl.lua",
"dlistbox.lua","dlistlayout.lua","dlistview.lua","dlistview_column.lua","dlistview_line.lua","dmenu.lua","dmenubar.lua","dmenuoption.lua","dmenuoptioncvar.lua","dmodelpanel.lua","dmodelselect.lua",
"dmodelselectmulti.lua","dnotify.lua","dnumberscratch.lua","dnumberwang.lua","dnumpad.lua","dnumslider.lua","dpanel.lua","dpanellist.lua","dpaneloverlay.lua","dpanelselect.lua","dprogress.lua",
"dproperties.lua","dpropertysheet.lua","drgbpicker.lua","dscrollbargrip.lua","dscrollpanel.lua","dshape.lua","dsizetocontents.lua","dslider.lua","dsprite.lua","dtextentry.lua","dtilelayout.lua",
"dtooltip.lua","dtree.lua","dtree_node.lua","dtree_node_button.lua","dverticaldivider.lua","dvscrollbar.lua","fingerposer.lua","fingervar.lua","imagecheckbox.lua","material.lua","matselect.lua",
"prop_boolean.lua","prop_combo.lua","prop_float.lua","prop_generic.lua","prop_int.lua","prop_vectorcolor.lua","propselect.lua","slidebar.lua","spawnicon.lua","vgui_panellist.lua","weapon_fists.lua",
"weapon_flechettegun.lua","weapon_medkit.lua"
}

local function searchDir(dir)
	local files, dirs = file.Find(dir .. "/*", "GAME")
	for k,v in pairs(files) do
		if string.find(v, ".lua") then
			table.insert(defaultLuaWhitelist, tostring(v))
		end
	end
	for k,v in pairs(dirs) do
		searchDir(dir.. "/" ..v)
	end
end

hook.Add("Initialize", "whitelistserverluafilesAS", function()
	Msg("AntiSkid is collecting a lua file whitelist! \n")
	local files, dirs = file.Find("lua/*", "GAME")
	local c_luaFiles = {}
	for k,v in pairs(files) do
		if string.find(v, ".lua") then
			table.insert(c_luaFiles, tostring(v))
		end
	end
	for k,v in pairs(dirs) do
		searchDir("lua/"..v)
	end
	table.Merge(defaultLuaWhitelist, c_luaFiles)
	Msg("AntiSkid has found " .. #defaultLuaWhitelist .. " lua files!\n")
end)


local function AntiSkidFileNameWhitelist(name)
	local data = file.Read("antiSkid/Whitelist.txt", "DATA")
	if data == "" then return end
	local luaNames = string.Split(data, ",")
	for k,v in pairs(luaNames) do
		if name == v then return true end
	end
	return false
end

net.Receive("antiSkidLuaFilesReturn", function(l,ply)
	local c_luaFiles = net.ReadTable()
	local checkTable = {}

	for k,v in pairs(c_luaFiles) do
		if !table.HasValue(defaultLuaWhitelist, tostring(v)) and !AntiSkidFileNameWhitelist(tostring(v)) then
			table.insert(checkTable, tostring(v))
		end
	end
	if #checkTable < 1 then return end
	local string = table.ToString(checkTable)
	AntiSkidOutputAdmin("Player: " .. ply:Name() .. " has returned invalid lua files:  " .. string.SetChar(string, string.len(string)-1, ""))
end)


-- Commands to add whitelist

hook.Add("PlayerSay", "antiSkidWhitelistAddition", function(ply,text)
	if not ply:IsSuperAdmin() then return end
	local temp = string.Split(text, " ")
	if temp[1] ~= "!as" then return end
	if #temp < 3 then ply:ChatPrint("!as add [luaname]/ !as scan [steamid]") return "" end
	if temp[2] ~= "add" and temp[2] ~= "scan" then ply:ChatPrint("!as add [luaname]/ !as scan [string]") return "" end
	local command = temp[2]
	local name = temp[3]
	if command == "add" then
		file.Append("antiSkid/Whitelist.txt", name .. ",")
		AntiSkidOutputAdmin("SuperAdmin: " .. ply:Name() .. " has added [" .. name .. "] to the luaScan whitelist!")
		return ""
	elseif command == "scan" then
		local ply = player.GetBySteamID(temp[3])
		if !ply:IsPlayer() then ply:ChatPrint("No player found!") return "" end
		scancom(ply, 2)
		return ""
	end
end)
