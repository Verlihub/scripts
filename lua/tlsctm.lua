-- TLS CTM 0.0.3.7
-- © 2021-2025 RoLex

--[[

	Following script partially fixes incompatibility
	in client to client connections due to outdated
	TLS version used for encrypted connection requests.
	Currently the MyINFO TLS flag is removed for old
	clients with TLS version 1.0, while newer clients
	with TLS version 1.3 and 1.2 keep their TLS flag.
	This seems to be the only solution right now. Note
	that Verlihub version 1.3.1.1 and above is required.
	Verlihub 1.3.1.11 and later now supports MyINFO TLS
	flag filter which allows non-encrypted connections
	from old to new clients. This should resolve the
	connection issue for any clients regardless of TLS
	version.

]]--

conf = {
	feed = true, -- notify to feed
	fnnc = 5, -- nick delay count
	fint = 1, -- info delay minutes
	fant = 60, -- reset delay minutes
	forc = true, -- force on unknown
	work = false -- dont touch this
}

seen = {
	nl = {},
	il = {},
	la = 0
}

function Main (file)
	local ok, ver = VH:GetConfig ((VH.ConfName or "config"), "hub_version")

	if ok and ver and # ver >= 7 then
		local v1, v2, v3, v4 = ver:match ("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") -- 1.2.3.4

		if v1 and v2 and v3 and v4 then
			ver = tonumber (tostring ("0.") .. tostring (v1) .. tostring (v2) .. tostring (v3) .. tostring (v4)) or -1

			if ver >= 0.1311 then -- verlihub 1.3.1.1 and above
				conf.work = true
				seen.la = os.time ()
			end
		end
	end

	if not conf.work then
		feed ("Please upgrade Verlihub in order to use this script.")
	end

	return 1
end

function VH_OnTimer (msec)
	if not conf.work then -- verlihub version old
		return 1
	end

	local now = os.time ()

	if now - seen.la < conf.fant * 60 then -- hours reset
		return 1
	end

	seen.nl = {}
	seen.il = {}
	seen.la = now
	return 1
end

function VH_OnParsedMsgMyINFO (nick, data)
	if not conf.work then -- verlihub version old
		return 1
	end

	local _, tls = VH:GetTLSVer (nick)
	tls = tonumber (tls or 0.0) or 0.0

	if tls >= 1.0 then -- we know tls version
		if tls == 1.0 then -- unset tls flag on 1.0
			VH:UnsetMyINFOFlag (nick, 16)
		end

		return 1
	end

	local cli, ver, fla = data:match ("<([^<]+) [Vv]:([^>]+),M:[^>]+>%$[^%$]*%$[^%$]*([^%$])%$[^%$]*%$[^%$]*%$$")

	if not cli then -- failed to parse tag
		if conf.feed then -- notify to feed
			feed ("Unknown tag from " .. nick .. ": " .. nmdc (data), nick, data:sub (15 + nick:len ()))
		end

		if conf.forc then -- force unset tls flag on unknown tag
			VH:UnsetMyINFOFlag (nick, 16)
		end

		return 1
	end

	fla = fla:byte () or 1

	if not stat (fla, 16) then -- tls flag is not present
		return 1
	end

	cli, ver = tagver (cli, ver) -- try to parse client version

	if ver < 0 then -- unable to parse or unknown client
		if conf.feed then -- notify to feed
			feed ("Unknown client from " .. nick .. ": " .. nmdc (data), nick, data:sub (15 + nick:len ()))
		end

		if conf.forc then -- force unset tls flag on unknown client
			VH:UnsetMyINFOFlag (nick, 16)
		end

		return 1
	end

	tls = tlsver (cli, ver) -- try to detect tls version

	if tls == 0.0 then -- we still dont know tls version
		if conf.feed then -- notify to feed
			feed ("Unknown TLS version from " .. nick .. ": " .. tostring (cli) .. " / " .. tostring (ver) .. " / " .. nmdc (data), nick, data:sub (15 + nick:len ()))
		end

		if conf.forc then -- force unset tls flag on unknown tls version
			VH:UnsetMyINFOFlag (nick, 16)
		end

	elseif tls == 1.0 then -- unset tls flag on 1.0
		VH:UnsetMyINFOFlag (nick, 16)
	end

	return 1
end

function tagver (id, ve)
	local ver, cli, mod, v1, v2, v3, v4 = -1, id, ve, 0, 0, 0, 0

	if cli ~= "FlylinkDC++" and cli ~= "Lama" then -- fake flylinkdc++
		if mod:match ("^r%d%d%d%-") or mod:match ("^%d%d%d%.%d%d%d%d%d") then
			cli = "FlylinkDC++"
		end
	end

	if cli == "ApexDC++" then -- apexdc++
		if mod:match ("^0%.") then -- pwdc++ move
			cli = "PWDC++"
		elseif mod:match ("^s%d+$") then -- speedmod
			cli = "ApexDC++s"
		end
	end

	if
		cli == "++" or -- dc++
		cli == "StrongDC++" or -- strongdc++
		cli == "RSX++" or -- rsx++
		cli == "gl++" or -- greylinkdc++
		cli == "P2P" or -- p2p
		cli == "pl++" or -- pelink++
		cli == "DDD++" or -- ddd++
		cli == "UC" or -- jucy
		cli == "oDC" -- operadc
	then
		v1, v2 = mod:match ("^(%d+)%.(%d+)$") -- 1.2

	elseif
		cli == "AirDC++" or -- airdc++
		cli == "AirDC++w" -- airdc++ web
	then
		mod = mod:gsub ("[b]?%-[0-9a-z%-]+$", "")
		mod = mod:gsub ("r%d+$", "")
		v1, v2 = mod:match ("^(%d+)%.(%d+)$") -- 1.2

		if not (v1 and v2) then
			v1, v2, v3 = mod:match ("^(%d+)%.(%d+)%.(%d+)$") -- 1.2.3
		end

	elseif
		cli == "PWDC++" -- pwdc++
	then
		v1, v2 = mod:match ("^(%d+)%.(%d+)$") -- 1.2

		if not (v1 and v2) then
			v1, v2, v3 = mod:match ("^(%d+)%.(%d+)%.(%d+)$") -- 1.2.3
		end

	elseif
		cli == "ApexDC++s" -- apexdc++ speedmod
	then
		mod = mod:gsub ("^s", "")
		v1 = mod:match ("^(%d+)$") -- 1

	elseif
		cli == "ApexDC++" or -- apexdc++
		cli == "EiskaltDC++" -- eiskaltdc++
	then
		v1, v2 = mod:match ("^(%d+)%.(%d+)$") -- 1.2

		if not (v1 and v2) then
			v1, v2, v3 = mod:match ("^(%d+)%.(%d+)%.(%d+)$") -- 1.2.3
		end

	elseif
		cli == "StrgDC++" -- strongdc++
	then
		mod = mod:gsub ("P$", "")
		v1, v2 = mod:match ("^(%d+)%.(%d+)$") -- 1.2

		if not (v1 and v2) then
			v1, v2, v3 = mod:match ("^(%d+)%.(%d+)%.(%d+)$") -- 1.2.3
		end

	elseif
		cli == "FlylinkDC++" or -- flylinkdc++
		cli == "Lama" -- lama
	then
		mod = mod:gsub ("^[%(]?[r]?(%d+)[%)]?", "%1")
		mod = mod:gsub ("%-beta(%d+)", "-%1")
		mod = mod:gsub ("%-x%d+", "")
		mod = mod:gsub ("%-rc%d+", "")
		mod = mod:gsub ("%-beta", "")
		mod = mod:gsub ("%-wine", "")
		mod = mod:gsub ("%-", ".")
		v2 = mod:match ("^(%d+)$") -- 2

		if not v2 then
			v2, v1 = mod:match ("^(%d+)%.(%d+)$") -- 2.1
		end

	elseif
		cli == "SSQLite++" or -- ssqlite++
		cli == "GreylinkDC++" or -- greylinkdc++
		cli == "DCGUI" -- valknut
	then
		v1, v2, v3 = mod:match ("^(%d+)%.(%d+)%.(%d+)$") -- 1.2.3

	elseif
		cli == "Shareaza" or -- shareaza
		cli == "FearDC" -- feardc
	then
		v1, v2, v3, v4 = mod:match ("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") -- 1.2.3.4

	elseif
		cli == "zK++" -- zk++
	then
		mod = mod:gsub ("d[0-9]+$", "")
		v1, v2 = mod:match ("^(%d+)%.(%d+)$") -- 1.2

	elseif
		cli == "ncdc" -- ncdc
	then
		mod = mod:gsub ("%-[0-9a-z%-]+$", "")
		v1, v2 = mod:match ("^(%d+)%.(%d+)$") -- 1.2

		if not (v1 and v2) then
			v1, v2, v3 = mod:match ("^(%d+)%.(%d+)%.(%d+)$") -- 1.2.3
		end
	end

	if v1 and v2 and v3 and v4 and not (v1 == 0 and v2 == 0 and v3 == 0 and v4 == 0) then
		ver = tonumber (tostring ("0.") .. tostring (v1) .. tostring (v2) .. tostring (v3) .. tostring (v4)) or -1
	end

	return cli, ver
end

function tlsver (id, ve)
	local lis = {
		["1.3"] = { -- tls 1.3
			["++"] = {0.0, 0.0}, -- dc++ none, fake: {0.0870, 1.0} dc++ 0.870
			["ApexDC++"] = {0.165, 1.0}, -- apexdc++ 1.6.5
			["ApexDC++s"] = {0.0, 0.0}, -- apexdc++ speedmod none
			["PWDC++"] = {0.0, 0.0}, -- pwdc++ none
			["AirDC++"] = {0.353, 1.0}, -- airdc++ 3.53
			["AirDC++w"] = {0.353, 1.0}, -- airdc++ web 3.53
			["EiskaltDC++"] = {0.2210, 1.0}, -- eiskaltdc++ 2.2.10
			["FlylinkDC++"] = {0.21972, 1.0}, -- flylinkdc++ .21972
			["Lama"] = {0.0, 0.0}, -- lama none
			["StrgDC++"] = {0.0, 0.0}, -- strongdc++ none
			["StrongDC++"] = {0.0, 1.0}, -- strongdc++ all
			["SSQLite++"] = {0.0, 0.0}, -- ssqlite++ none
			["GreylinkDC++"] = {0.0, 0.0}, -- greylinkdc++ none
			["RSX++"] = {0.0, 0.0}, -- rsx++ none
			["gl++"] = {0.0, 0.0}, -- greylinkdc++ none
			["P2P"] = {0.0, 0.0}, -- p2p none
			["pl++"] = {0.0, 0.0}, -- pelinkdc++ none
			["DDD++"] = {0.0, 0.0}, -- ddd++ none
			["Shareaza"] = {0.0, 0.0}, -- shareaza none
			["zK++"] = {0.0, 0.0}, -- zk++ none
			["ncdc"] = {0.0, 0.0}, -- ncdc none
			["UC"] = {0.0, 0.0}, -- jucy none
			["oDC"] = {0.0, 0.0}, -- operadc none
			["DCGUI"] = {0.0, 0.0}, -- valknut none
			["FearDC"] = {0.0, 1.0} -- feardc all
		},
		["1.2"] = { -- tls 1.2
			["++"] = {0.0, 0.0}, -- dc++ none, fake: {0.0850, 0.0869} dc++ 0.850
			["ApexDC++"] = {0.1514, 0.164}, -- apexdc++ 1.5.14
			["ApexDC++s"] = {0.0, 0.0}, -- apexdc++ speedmod none
			["PWDC++"] = {0.0, 0.0}, -- pwdc++ none
			["AirDC++"] = {0.300, 0.352}, -- airdc++ 3.00
			["AirDC++w"] = {0.300, 0.352}, -- airdc++ web 3.00
			["EiskaltDC++"] = {0.0, 0.0}, -- eiskaltdc++ none
			["FlylinkDC++"] = {0.19482, 0.21971}, -- flylinkdc++ .19482
			["Lama"] = {0.0, 0.0}, -- lama none
			["StrgDC++"] = {0.0, 0.0}, -- strongdc++ none
			["StrongDC++"] = {0.0, 1.0}, -- strongdc++ all
			["SSQLite++"] = {0.0, 0.0}, -- ssqlite++ none
			["GreylinkDC++"] = {0.0, 0.0}, -- greylinkdc++ none
			["RSX++"] = {0.0, 0.0}, -- rsx++ none
			["gl++"] = {0.0, 0.0}, -- greylinkdc++ none
			["P2P"] = {0.0, 0.0}, -- p2p none
			["pl++"] = {0.0, 0.0}, -- pelinkdc++ none
			["DDD++"] = {0.0, 0.0}, -- ddd++ none
			["Shareaza"] = {0.0, 0.0}, -- shareaza none
			["zK++"] = {0.0, 0.0}, -- zk++ none
			["ncdc"] = {0.0, 0.0}, -- ncdc none
			["UC"] = {0.0, 0.0}, -- jucy none
			["oDC"] = {0.0, 0.0}, -- operadc none
			["DCGUI"] = {0.0, 0.0}, -- valknut none
			["FearDC"] = {0.0, 1.0} -- feardc all
		},
		["1.0"] = { -- tls 1.0
			["++"] = {0.0, 1.0}, -- dc++ none, set as 1.0, fake: {0.0707, 0.0849} dc++ 0.707
			["ApexDC++"] = {0.120, 0.1513}, -- apexdc++ 1.2.0
			["ApexDC++s"] = {0.0, 1.0}, -- apexdc++ speedmod none, set as 1.0
			["PWDC++"] = {0.0, 1.0}, -- pwdc++ unknown, set as 1.0
			["AirDC++"] = {0.200, 0.299}, -- airdc++ 2.00
			["AirDC++w"] = {0.200, 0.299}, -- airdc++ web 2.00
			["EiskaltDC++"] = {0.0, 0.229}, -- eiskaltdc++ unknown, set as 1.0
			["FlylinkDC++"] = {0.0, 0.19481}, -- flylinkdc++ unknown, set as 1.0
			["Lama"] = {0.0, 1.0}, -- lama none, set as 1.0
			["StrgDC++"] = {0.0, 1.0}, -- strongdc++ unknown, set as 1.0
			["StrongDC++"] = {0.0, 1.0}, -- strongdc++ unknown, set as 1.0
			["SSQLite++"] = {0.0, 1.0}, -- ssqlite++ all, set as 1.0
			["GreylinkDC++"] = {0.0, 1.0}, -- greylinkdc++ all, set as 1.0
			["RSX++"] = {0.0, 1.0}, -- rsx++ all, set as 1.0
			["gl++"] = {0.0, 1.0}, -- greylinkdc++ all, set as 1.0
			["P2P"] = {0.0, 1.0}, -- p2p all, set as 1.0
			["pl++"] = {0.0, 1.0}, -- pelinkdc++ all, set as 1.0
			["DDD++"] = {0.0, 1.0}, -- ddd++ all, set as 1.0
			["Shareaza"] = {0.0, 1.0}, -- shareaza none, set as 1.0
			["zK++"] = {0.0, 1.0}, -- zk++ unknown, set as 1.0
			["ncdc"] = {0.0, 1.0}, -- ncdc unknown, set as 1.0
			["UC"] = {0.0, 1.0}, -- jucy unknown, set as 1.0
			["oDC"] = {0.0, 1.0}, -- operadc none, set as 1.0
			["DCGUI"] = {0.0, 1.0}, -- valknut none, set as 1.0
			["FearDC"] = {0.0, 1.0} -- feardc none, set as 1.0
		}
	}

	local res = 0.0

	for tls, cli in pairs (lis) do
		for tag, ver in pairs (cli) do
			if tag == id and (ver [1] > 0.0 or ver [2] > 0.0) and ve >= ver [1] and ve <= ver [2] then
				res = tonumber (tls)
				break
			end
		end

		if res > 0.0 then
			break
		end
	end

	return res
end

function stat (flag, need)
	local res, bit, a, b = 0, 1, flag, need

	while a > 0 and b > 0 do
		if (a % 2) == 1 and (b % 2) == 1 then
			res = res + bit
		end

		bit = bit * 2
		a = math.floor (a / 2)
		b = math.floor (b / 2)
	end

	return res == need
end

if not _VERSION:sub (5):match ("^5%.[012]") then -- 5.3 and later
	load ("function stat (flag, need) return (flag & need) == need end")
end

function nmdc (data)
	local safe = tostring (data)
	safe = safe:gsub ("%$", "&#36;")
	safe = safe:gsub ("|", "&#124;")
	return safe
end

function feed (data, nick, info)
	if nick and info then -- not too often
		if not seen.nl [nick] then
			seen.nl [nick] = 0
		end

		if seen.nl [nick] >= conf.fnnc then -- times delay
			return
		end

		seen.nl [nick] = seen.nl [nick] + 1
		local nohc = info:gsub (",H:%d+/%d+/%d+,", ",H:0/0/0,") -- skip hub count

		if not seen.il [nohc] then
			seen.il [nohc] = 0
		end

		local now = os.time ()

		if now - seen.il [nohc] < conf.fint * 60 then -- minutes delay
			return
		end

		seen.il [nohc] = now
	end

	VH:SendToOpChat ("[TLSCTM] " .. data)
end

-- end of file