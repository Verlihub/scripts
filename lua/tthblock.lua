-- TTH Block 0.0.3.5
-- © 2020-2022 RoLex

list = {}

conf = {
	comm = "tthblock",									-- statistics command
	from = "",											-- notification feed nick, empty for auto
	tell = 0,											-- notification to user
	clas = 0,											-- command usage class, zero for auto
	feed = 0,											-- notification feed class, zero for auto
	skip = 0,											-- skip user class, zero for auto
	wait = 10800,										-- seconds before notification
	addr = "",											-- server listen address, empty for auto
	port = 20201,										-- server listen port
	secs = 5,											-- search interval in seconds
	mins = 360,											-- update interval in minutes
	kick = false,										-- block or kick action
	text = "",											-- kick action reason
	list = "https://te-home.net/tthblock.php?do=load"	-- update tth list url
}

serv = {
	sock = nil,
	work = nil,
	last = 0,
	mins = 0,
	item = 0,
	vers = 0,
	list = {}
}

stat = {}

function Main (file)
	local _, vers = VH:GetConfig ((VH.ConfName or "config"), "hub_version")

	if vers and # vers >= 7 then
		local v1, v2, v3, v4 = vers:match ("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") -- 1.2.3.4

		if v1 and v2 and v3 and v4 then
			serv.vers = tonumber (tostring ("0.") .. tostring (v1) .. tostring (v2) .. tostring (v3) .. tostring (v4)) or 0
		end
	end

	local _, rows = VH:SQLQuery (
		"select `variable`, `value` from `lua_ledo_conf` where " ..
		"`variable` = 'enablesearfilt' or " ..
		"`variable` = 'addsefifeed' or " ..
		"`variable` = 'sefifeednick' or " ..
		"`variable` = 'addledobot' or " ..
		"`variable` = 'ledobotnick' or " ..
		"`variable` = 'useextrafeed' or " ..
		"`variable` = 'extrafeednick' or " ..
		"`variable` = 'avsearchint' or " ..
		"`variable` = 'avsearservaddr' or " ..
		"`variable` = 'sefireason' or " ..
		"`variable` = 'thirdacttime' or " ..
		"`variable` = 'mincommandclass' or " ..
		"`variable` = 'classnotisefi' or " ..
		"`variable` = 'scanbelowclass'"
	)

	local test = {}

	for row = 0, rows - 1 do
		local _, var, val = VH:SQLFetch (row)
		test [var] = (tonumber (val) or val or "")
	end

	if # conf.from == 0 then -- feed nick
		if test.enablesearfilt == 1 and test.addsefifeed == 1 and # test.sefifeednick > 0 then
			conf.from = test.sefifeednick
		elseif test.useextrafeed == 1 and # test.extrafeednick > 0 then
			conf.from = test.extrafeednick
		elseif test.addledobot == 1 and # test.ledobotnick > 0 then
			conf.from = test.ledobotnick
		else
			conf.from = VH.OpChat
		end
	end

	if # conf.addr == 0 then -- server address
		if test.avsearchint > 0 and # test.avsearservaddr > 0 then
			conf.addr = test.avsearservaddr
		else
			conf.addr = "0.0.0.0"
		end
	end

	if conf.kick and # conf.text == 0 then -- kick reason
		if # test.sefireason > 0 then
			conf.text = test.sefireason
		else
			conf.text = "Forbidden search request or result detected: *"
		end

		conf.text = conf.text .. "     #_ban_"

		if # test.thirdacttime > 0 then
			conf.text = conf.text .. test.thirdacttime
		else
			conf.text = conf.text .. "1d"
		end
	end

	if conf.clas == 0 then -- command class
		if test.mincommandclass < 11 then
			conf.clas = test.mincommandclass
		else
			conf.clas = 5
		end
	end

	if conf.feed == 0 then -- feed class
		if test.classnotisefi < 11 then
			conf.feed = test.classnotisefi
		else
			conf.feed = 4
		end
	end

	if conf.skip == 0 then -- skip class
		if test.scanbelowclass < 11 then
			conf.skip = test.scanbelowclass
		else
			conf.skip = 2
		end
	end

	conf.skip = conf.skip - 1
	getlist () -- create lists

	local res, err = pcall ( -- start server
		function ()
			serv.sock = require ("socket")
		end
	)

	if res and serv.sock then
		local udp, err = serv.sock.udp ()

		if udp then
			udp:settimeout (0)
			local res, err = udp:setsockname (conf.addr, conf.port)

			if res then
				serv.work = udp
				sendfeed ("TTH server running using " .. nmdcsafe (serv.sock._VERSION) .. ": " .. conf.addr .. ":" .. _tostring (conf.port))

			else
				udp:close ()
				sendfeed ("Failed starting TTH server: " .. nmdcsafe (err or "Unknown"))
			end

		else
			sendfeed ("Failed creating TTH server: " .. nmdcsafe (err or "Unknown"))
		end

	else
		sendfeed ("Failed loading LuaSocket module: " .. nmdcsafe (err or "Unknown"))
	end

	return 1
end

function UnLoad ()
	if serv.work then -- stop server
		serv.work:close ()
		serv.work = nil
		sendfeed ("TTH server stopped: " .. conf.addr .. ":" .. _tostring (conf.port))
	end

	return 1
end

function VH_OnTimer (msec)
	if not serv.work then -- nothing to do
		return 1
	end

	for tot = 1, 10 do -- active result, client sends 10
		local data, addr, port = serv.work:receivefrom ()

		if not data or not addr or not port or # data == 0 or # addr == 0 or addr == "timeout" then -- no data
			break
		end

		for part in data:gmatch ("[^|]+") do
			local nick, path, tth = part:match ("%$SR ([^ ]+) ([^" .. string.char (5) .. "]+)" .. string.char (5) .. "%d+ %d+/%d+" .. string.char (5) .. "TTH:([A-Z2-7]+) %(.+%)$")

			if nick and path and tth and # tth == 39 and list [tth] then -- check tth
				local _, clas = VH:GetUserClass (nick) -- check class

				if clas < 0 or clas > conf.skip then
					break
				end

				local _, uddr = VH:GetUserIP (nick) -- check source

				if uddr ~= addr then
					break
				end

				VH:ScriptCommand ("avdb_user_detect", nick .. " " .. addr .. " " .. path) -- to catch in ledokol
				list [tth] = list [tth] + 1
				break
			end

			serv.sock.sleep (0.001) -- unload cpu
		end

		serv.sock.sleep (0.001) -- unload cpu
	end

	local now = os.time ()

	if os.difftime (now, serv.last) >= conf.secs then -- search interval
		local tot = # serv.list

		if tot > 0 then
			if serv.item >= tot then -- next item
				serv.item = 1
			else
				serv.item = serv.item + 1
			end

			local _, wait = VH:GetConfig (VH.ConfName, "delayed_search")
			wait = tonumber (wait or 1) or 1

			if VH.GetNickList and VH.IsBot and VH.InUserSupports then
				local _, full = VH:GetNickList ()

				for nick in full:sub (11):gmatch ("[^ %$]+") do
					local _, clas = VH:GetUserClass (nick)

					if clas >= 0 and clas <= conf.skip and not VH:IsBot (nick) then
						local _, info = VH:GetMyINFO (nick)

						if not info:match ("%$0%$$") then
							local _, tths = VH:InUserSupports (nick, "TTHS")

							if (type (tths) == "number" and tonumber (tths) == 1) or tths then
								info = "$SA " .. serv.list [serv.item] .. " " .. conf.addr .. ":" .. _tostring (conf.port) .. "|"
							else
								info = "$Search " .. conf.addr .. ":" .. _tostring (conf.port) .. " F?F?0?9?TTH:" .. serv.list [serv.item] .. "|"
							end

							if serv.vers >= 0.10215 then
								VH:SendToUser (info, nick, wait)
							else
								VH:SendToUser (info, nick)
							end
						end
					end
				end

			elseif serv.vers >= 0.10215 then
				VH:SendToClass ("$Search " .. conf.addr .. ":" .. _tostring (conf.port) .. " F?F?0?9?TTH:" .. serv.list [serv.item] .. "|", 0, conf.skip, wait)
			else
				VH:SendToClass ("$Search " .. conf.addr .. ":" .. _tostring (conf.port) .. " F?F?0?9?TTH:" .. serv.list [serv.item] .. "|", 0, conf.skip)
			end
		end

		serv.last = now
	end

	if os.difftime (now, serv.mins) >= conf.mins * 60 then -- update interval
		getlist ()
	end

	return 1
end

function VH_OnParsedMsgSR (nick, data) -- passive result
	local _, clas = VH:GetUserClass (nick) -- check class

	if clas < 0 or clas > conf.skip then
		return 1
	end

	local path, tth = data:match ("%$SR [^ ]+ ([^" .. string.char (5) .. "]+)" .. string.char (5) .. "%d+ %d+/%d+" .. string.char (5) .. "TTH:([A-Z2-7]+) %(.+%)" .. string.char (5) .. "[^ ]+$")

	if not path or not tth or # tth ~= 39 or not list [tth] then -- check tth
		return 1
	end

	local _, addr = VH:GetUserIP (nick)
	VH:ScriptCommand ("avdb_user_detect", nick .. " " .. addr .. " " .. path) -- to catch in ledokol
	list [tth] = list [tth] + 1
	return 0
end

function VH_OnParsedMsgSearch (nick, data) -- search request
	local _, clas = VH:GetUserClass (nick) -- check class

	if clas < 0 or clas > conf.skip then
		return 1
	end

	local tth = data:match ("^%$Search [^ ]+ [TF]%?[TF]%?%d+%?9%?TTH:([A-Z2-7]+)$")

	if not tth or # tth ~= 39 or not list [tth] then -- check tth
		return 1
	end

	if conf.kick then
		local text = conf.text:gsub ("%*", tth)
		VH:KickUser (VH.HubSec, nick, text)

	else
		VH:ScriptCommand ("sefi_user_block", _tostring (conf.tell) .. " " .. nick .. " " .. tth) -- to catch in ledokol
	end

	list [tth] = list [tth] + 1
	local now = os.time ()

	if not stat [nick] or os.difftime (now, stat [nick]) >= conf.wait then -- not too often
		stat [nick] = now
		local _, addr = VH:GetUserIP (nick)
		local _, code = VH:GetUserCC (nick)

		if code and # code == 2 then
			addr = addr .. "." .. code
		end

		sendfeed ("TTH " .. (conf.kick and "kick" or "block") .. " from " .. nick .. " with IP " .. addr .. " and class " .. _tostring (clas) .. ": " .. tth)
	end

	return 0
end

function VH_OnUserLogout (nick, addr)
	stat [nick] = nil
	return 1
end

function VH_OnHubCommand (nick, data, op, pm)
	local _, clas = VH:GetUserClass (nick)

	if clas < conf.clas then
		return 1
	end

	if data:sub (2, # conf.comm + 1) == conf.comm then
		local sort, line = {}, ""

		for tth, hit in pairs (list) do
			if hit > 1 then
				table.insert (sort, {hit - 1, tth})
			end
		end

		if # sort > 0 then
			table.sort (sort,
				function (one, two)
					return one [1] > two [1]
				end
			)

			for pos, tth in pairs (sort) do
				line = line .. " " .. _tostring (pos) .. ". " .. tth [2] .. " = " .. _tostring (tth [1]) .. "\r\n"
			end

		else
			line = " Nothing yet.\r\n"
		end

		line = "TTH block statistics:\r\n\r\n" .. line

		if tonumber (pm) == 1 then
			VH:SendToUser ("$To: " .. nick .. " From: " .. VH.HubSec .. " $<" .. VH.HubSec .. "> " .. line .. "|", nick)
		else
			VH:SendToUser ("<" .. VH.HubSec .. "> " .. line .. "|", nick)
		end

		return 0
	end

	return 1
end

function getlist ()
	local _, path = VH:GetVHCfgDir ()
	path = path .. "/" .. conf.comm .. ".tth"
	os.execute ("curl --get --location --max-redirs 1 --retry 2 --connect-timeout 5 --max-time 10 --user-agent \"Mozilla/5.0 (compatible; TTH Block/0.0.3.4; +https://ledo.feardc.net/other/)\" --silent --output \"" .. path .. "\" \"" .. conf.list .. "\"")
	local file = io.open (path, "r")

	if file then
		file:close ()
		local temp, have = {}, false

		for tth in io.lines (path) do
			tth = tth:gsub ("\r", "") -- get rid of newline
			tth = tth:gsub ("\n", "")

			if # tth == 39 then
				temp [tth] = 1
				have = true
			end
		end

		if have then
			serv.list = {}

			for tth, _ in pairs (temp) do
				temp [tth] = list [tth] or 1
				table.insert (serv.list, tth)
			end

			list = temp
		end

		os.remove (path)
	end

	conf.mins = os.time ()
end

function sendfeed (data)
	if conf.from == VH.OpChat then
		VH:SendToOpChat ("[0" .. _tostring (conf.feed) .. "] " .. data)
		VH:ScriptCommand ("opchat_to_all", "[" .. _tostring (conf.feed) .. "] <" .. conf.from .. "> " .. data) -- to catch in ledokol

	else
		VH:SendPMToAll ("[0" .. _tostring (conf.feed) .. "] " .. data, conf.from, conf.feed, 10)
	end
end

function nmdcsafe (data)
	local safe = _tostring (data)
	safe = safe:gsub ("%$", "&#36;")
	safe = safe:gsub ("|", "&#124;")
	return safe
end

function _tostring (data)
	if type (data) == "number" then
		return string.format ("%d", data)
	end

	return tostring (data)
end

-- end of file