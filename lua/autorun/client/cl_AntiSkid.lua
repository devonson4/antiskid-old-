--------------------
// Made by Dev for Werwolf //
--------------------
local antiSkid = table.Copy(_G)

antiSkid.net.Receive("antiSkidConCommandUpdate", function()
	local c_commands = antiSkid.concommand.GetTable()
	local c_commandsToSend = {}
	for k,v in antiSkid.pairs(c_commands) do
		table.insert(c_commandsToSend,tostring(k))
	end
	
	antiSkid.net.Start("antiSkidConCommandUpdate")
		antiSkid.net.WriteTable(c_commandsToSend)
	antiSkid.net.SendToServer()
end)

antiSkid.net.Receive("antiSkidConvarCheck2", function()
	local c_convars = {
	antiSkid.GetConVarString("sv_allowcslua"),
	antiSkid.GetConVarString("sv_cheats"),
	antiSkid.GetConVarString("host_timescale"),
	}
	antiSkid.net.Start("antiSkidConvarReturn")
		antiSkid.net.WriteTable(c_convars)
	antiSkid.net.SendToServer()
end)


antiSkid.net.Receive("antiSkidLuaFilesCheck", function()
	local files, dirs = antiSkid.file.Find("lua/*", "GAME")
	local c_luaFiles = {}
	for k,v in antiSkid.pairs(files) do
		if string.find(v, ".lua") then
			table.insert(c_luaFiles, tostring(v))
		end
	end
	--for k,v in antiSkid.pairs(dirs) do
		--local temp = antiSkid.file.Find("lua/" .. v .. "/*.lua", "GAME")
		--for j,l in antiSkid.pairs(temp) do
			--if string.find(l, ".lua") and !table.HasValue(c_luaFiles, tostring(l)) then
			--	table.insert(c_luaFiles, tostring(l))
			--end
		--end
	--end
	antiSkid.net.Start("antiSkidLuaFilesReturn")
		antiSkid.net.WriteTable(c_luaFiles)
	antiSkid.net.SendToServer()
end)

antiSkid.net.Receive("antiSkid_message", function()
	local string = net.ReadString()

	chat.AddText(Color(82,77,73), "[", Color(212,17,36), "AntiSkid", Color(82,77,73), "] ", Color(255,255,255), string)
end)

antiSkid.net.Receive("antiSkidConCommandAmount", function()
	local c_commands = antiSkid.concommand.GetTable()
	local c_commandsToSend = {}
	for k,v in antiSkid.pairs(c_commands) do
		table.insert(c_commandsToSend,tostring(k))
	end
	
	antiSkid.net.Start("antiSkidConCommandAmount")
		antiSkid.net.WriteTable(c_commandsToSend)
	antiSkid.net.SendToServer()
end)