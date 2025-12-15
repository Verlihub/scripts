-- Silent Block 0.1.3.2
-- Â© 2014-2020 RoLex

conf = {
	class = 5
}

bips = {}

function Main (file)
	VH:SQLQuery ("create table if not exists `lua_silentblock` (`addr` varchar(15) not null primary key)")
	local _, rows = VH:SQLQuery ("select `addr` from `lua_silentblock`")

	for row = 0, rows - 1 do
		local _, addr = VH:SQLFetch (row)
		bips [addr] = 0
	end

	return 1
end

function VH_OnNewConn (addr)
	if bips [addr] then
		bips [addr] = bips [addr] + 1
		return 0
	end

	return 1
end

function VH_OnHubCommand (nick, data, op, pm)
	if data:sub (2, 3) == "sb" then
		local _, class = VH:GetUserClass (nick)

		if tonumber (class) >= conf.class then
			local cmd = data:sub (5, 7)

			if cmd == "add" then
				local addr = data:sub (9)

				if # addr > 0 then
					if bips [addr] then
						sendreply (nick, "Silent block already in list: " .. addr, pm)
					else
						VH:SQLQuery ("insert ignore into `lua_silentblock` (`addr`) values ('" .. sqlchars (addr) .. "')")
						bips [addr] = 0
						sendreply (nick, "Silent block added to list: " .. addr, pm)
					end
				else
					sendreply (nick, "Missing silent block parameter.", pm)
				end

			elseif cmd == "del" then
				local addr = data:sub (9)

				if # addr > 0 then
					if addr == "*" then
						VH:SQLQuery ("truncate table `lua_silentblock`")
						bips = {}
						sendreply (nick, "Silent block list cleared.", pm)
					else
						if bips [addr] then
							VH:SQLQuery ("delete ignore from `lua_silentblock` where `addr` = '" .. sqlchars (addr) .. "'")
							bips [addr] = nil
							sendreply (nick, "Silent block removed from list: " .. addr, pm)
						else
							sendreply (nick, "Silent block not in list: " .. addr, pm)
						end
					end
				else
					sendreply (nick, "Missing silent block parameter.", pm)
				end

			elseif cmd == "lst" then
				local list = ""

				for bip, cnt in pairs (bips) do
					list = list .. " " .. bip .. " = " .. _tostring (cnt) .. "\r\n"
				end

				if # list > 0 then
					sendreply (nick, "Silent block list:\r\n\r\n" .. list, pm)
				else
					sendreply (nick, "Silent block list is empty.", pm)
				end

			else
				sendreply (nick, "Unknown silent block command.", pm)
			end

			return 0
		end
	end

	return 1
end

function sendreply (nick, data, pm)
	if tonumber (pm) == 1 then
		VH:SendToUser ("$To: " .. nick .. " From: " .. VH.HubSec .. " $<" .. VH.HubSec .. "> " .. data .. "|", nick)
	else
		VH:SendToUser ("<" .. VH.HubSec .. "> " .. data .. "|", nick)
	end
end

function sqlchars (data)
	local safe = data
	safe = safe:gsub (string.char (92), string.char (92, 92))
	safe = safe:gsub (string.char (34), string.char (92, 34))
	safe = safe:gsub (string.char (39), string.char (92, 39))
	return safe
end

function _tostring (val)
	if type (val) == "number" then
		return string.format ("%d", val)
	end

	return tostring (val)
end

-- end of file