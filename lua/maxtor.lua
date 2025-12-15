-- MaxTor 0.0.2.1
-- © 2021 RoLex

conf = {
	comm = "maxtor",									-- list command
	from = "",											-- feed nick
	clas = 10,											-- usage class
	tors = 100,											-- tor user limit
	wait = 15,											-- feed interval
	mins = 30,											-- update interval
	list = {											-- update list urls
		"https://ledo.feardc.net/mirror/torexit.list",
		"https://ledo.feardc.net/mirror/torserver.list"
	}
}

sets = {
	tors = 0,
	wait = 0,
	mins = 0,
	list = {}
}

function Main (file)
	if # conf.from == 0 then
		conf.from = VH.OpChat
	end

	return 1
end

function VH_OnTimer (msec)
	local now = os.time ()

	if os.difftime (now, sets.mins) < conf.mins * 60 then
		return 1
	end

	local _, path = VH:GetVHCfgDir ()
	path = path .. "/" .. conf.comm .. ".temp"
	local temp, have = {}, false

	for _, url in pairs (conf.list) do
		os.execute ("curl --get --location --max-redirs 1 --retry 2 --connect-timeout 5 --max-time 10 --user-agent \"Mozilla/5.0 (compatible; MaxTor/0.0.2.1; +https://ledo.feardc.net/other/)\" --silent --output \"" .. path .. "\" \"" .. url .. "\"")
		local file = io.open (path, "r")

		if file then
			file:close ()

			for addr in io.lines (path) do
				addr = addr:gsub ("\r", "")
				addr = addr:gsub ("\n", "")

				if addr:match ("^%d+%.%d+%.%d+%.%d+$") then
					temp [addr] = {}
					have = true
				end
			end

			os.remove (path)
		end
	end

	if have then
		for addr, list in pairs (sets.list) do
			if temp [addr] then
				temp [addr] = list

			else
				for _, user in pairs (list) do
					sets.tors = sets.tors - 1
				end
			end
		end

		sets.list = temp
	end

	sets.mins = now
	return 1
end

function VH_OnNewConn (addr, port, sead, sepo)
	if not sets.list [addr] or sets.tors < conf.tors then
		return 1
	end

	local now = os.time ()

	if os.difftime (now, sets.wait) < conf.wait * 60 then
		return 0
	end

	local line = "MaxTor limit reached: " .. _tostring (sets.tors) .. " of " .. _tostring (conf.tors)

	if conf.from == VH.OpChat then
		VH:SendToOpChat ("[0" .. _tostring (conf.clas) .. "] " .. line)
		VH:ScriptCommand ("opchat_to_all", "[" .. _tostring (conf.clas) .. "] <" .. conf.from .. "> " .. line) -- to catch in ledokol

	else
		VH:SendPMToAll ("[0" .. _tostring (conf.clas) .. "] " .. line, conf.from, conf.clas, 10)
	end

	sets.wait = now
	return 0
end

function VH_OnUserLogin (nick, addr)
	local list = sets.list [addr]

	if not list then
		return 1
	end

	local have = false

	if # list > 0 then
		for _, user in pairs (list) do
			if nick == user then
				have = true
				break
			end
		end
	end

	if not have then
		table.insert (sets.list [addr], nick)
		sets.tors = sets.tors + 1
	end

	return 1
end

function VH_OnUserLogout (nick, addr)
	local list = sets.list [addr]

	if not list then
		return 1
	end

	for pos, user in pairs (list) do
		if nick == user then
			table.remove (sets.list [addr], pos)
			sets.tors = sets.tors - 1
			break
		end
	end

	return 1
end

function VH_OnHubCommand (nick, data, op, pm)
	local _, clas = VH:GetUserClass (nick)

	if clas < conf.clas or data:sub (2, # conf.comm + 1) ~= conf.comm then
		return 1
	end

	local line, pos, tors = "", 0, 0

	for addr, list in pairs (sets.list) do
		tors = tors + 1

		if # list > 0 then
			local _, code = VH:GetIPCC (addr)
			line = line .. " @ " .. addr .. "." .. (code or "??") .. "\r\n"

			for _, user in pairs (list) do
				pos = pos + 1
				line = line .. "\t" .. _tostring (pos) .. ". " .. user .. "\r\n"
			end
		end
	end

	if pos > 0 then
		line = "MaxTor list: " .. _tostring (sets.tors) .. " of " .. _tostring (conf.tors) .. " at " .. _tostring (tors) .. "\r\n\r\n" .. line
	else
		line = "Nothing yet at " .. _tostring (tors) .. "."
	end

	if tonumber (pm) == 1 then
		VH:SendToUser ("$To: " .. nick .. " From: " .. VH.HubSec .. " $<" .. VH.HubSec .. "> " .. line .. "|", nick)
	else
		VH:SendToUser ("<" .. VH.HubSec .. "> " .. line .. "|", nick)
	end

	return 0
end

function _tostring (data)
	if type (data) == "number" then
		return string.format ("%d", data)
	end

	return tostring (data)
end

-- end of file