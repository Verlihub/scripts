-- Mini Gag 0.2.2.2
-- © 2013-2020 RoLex

conf = {
	gag = 1, -- maximum user class to check for gag
	feed = 10, -- mimum operator class to see feed notifications
	conf = 10, -- mimum operator class to use script commands
}

gags = {
	code = { -- country gag list
		--"IT",
		--"RO"
	},
	range = { -- range gag list
		--"93.46.152.0-93.46.153.255",
		--"79.13.205.0-79.13.208.255"
	}
}

function Main (script)
	VH:SQLQuery ("create table if not exists `lua_minigag` (`item` varchar(31) not null primary key, `type` varchar(5) not null)")
	local _, rows = VH:SQLQuery ("select * from `lua_minigag`")

	for row = 0, rows - 1 do
		local _, item, gagtype = VH:SQLFetch (row)
		table.insert (gags [gagtype], item)
	end

	return 1
end

function VH_OnHubCommand (nick, data, flagop, flagpm)
	if data:sub (2, 3) == "mg" then
		local _, class = VH:GetUserClass (nick)

		if class >= conf.conf then
			if data:sub (5, 7) == "add" then
				if data:sub (9, 12) == "code" then
					if # data:sub (14) < 2 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too short.|", nick)
					elseif # data:sub (14) > 2 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too long.|", nick)
					else
						item = data:sub (14):upper ()

						for _, cc in pairs (gags.code) do
							if item == cc then
								VH:SendToUser ("<" .. VH.HubSec .. "> Item already in list.|", nick)
								return 0
							end
						end

						table.insert (gags.code, item)
						VH:SQLQuery ("insert into `lua_minigag` (`item`, `type`) values ('" .. sqlchars (item) .. "', 'code')")
						VH:SendToUser ("<" .. VH.HubSec .. "> Item added to list.|", nick)
					end
				elseif data:sub (9, 13) == "range" then
					if # data:sub (15) < 15 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too short.|", nick)
					elseif # data:sub (15) > 31 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too long.|", nick)
					else
						item = data:sub (15)

						for _, range in pairs (gags.range) do
							if item == range then
								VH:SendToUser ("<" .. VH.HubSec .. "> Item already in list.|", nick)
								return 0
							end
						end

						table.insert (gags.range, item)
						VH:SQLQuery ("insert into `lua_minigag` (`item`, `type`) values ('" .. sqlchars (item) .. "', 'range')")
						VH:SendToUser ("<" .. VH.HubSec .. "> Item added to list.|", nick)
					end
				else
					VH:SendToUser ("<" .. VH.HubSec .. "> Unknown item type.|", nick)
				end
			elseif data:sub (5, 7) == "del" then
				if data:sub (9, 12) == "code" then
					if # data:sub (14) < 2 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too short.|", nick)
					elseif # data:sub (14) > 2 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too long.|", nick)
					else
						item = data:sub (14):upper ()

						for id, cc in pairs (gags.code) do
							if item == cc then
								table.remove (gags.code, id)
								VH:SQLQuery ("delete from `lua_minigag` where `item` = '" .. sqlchars (item) .. "' and `type` = 'code'")
								VH:SendToUser ("<" .. VH.HubSec .. "> Item deleted from list.|", nick)
								return 0
							end
						end

						VH:SendToUser ("<" .. VH.HubSec .. "> Item not in list.|", nick)
					end
				elseif data:sub (9, 13) == "range" then
					if # data:sub (15) < 15 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too short.|", nick)
					elseif # data:sub (15) > 31 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Item too long.|", nick)
					else
						item = data:sub (15)

						for id, range in pairs (gags.range) do
							if item == range then
								table.remove (gags.range, id)
								VH:SQLQuery ("delete from `lua_minigag` where `item` = '" .. sqlchars (item) .. "' and `type` = 'range'")
								VH:SendToUser ("<" .. VH.HubSec .. "> Item deleted from list.|", nick)
								return 0
							end
						end

						VH:SendToUser ("<" .. VH.HubSec .. "> Item not in list.|", nick)
					end
				else
					VH:SendToUser ("<" .. VH.HubSec .. "> Unknown item type.|", nick)
				end
			elseif data:sub (5, 8) == "list" then
				if data:sub (10, 13) == "code" then
					list = ""

					for _, cc in pairs (gags.code) do
						list = list .. " " .. cc .. "\r\n"
					end

					if # list > 0 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Country list:\r\n\r\n" .. list .. "|", nick)
					else
						VH:SendToUser ("<" .. VH.HubSec .. "> Country list is empty.|", nick)
					end
				elseif data:sub (10, 14) == "range" then
					list = ""

					for _, range in pairs (gags.range) do
						list = list .. " " .. range .. "\r\n"
					end

					if # list > 0 then
						VH:SendToUser ("<" .. VH.HubSec .. "> Range list:\r\n\r\n" .. list .. "|", nick)
					else
						VH:SendToUser ("<" .. VH.HubSec .. "> Range list is empty.|", nick)
					end
				else
					VH:SendToUser ("<" .. VH.HubSec .. "> Unknown item type.|", nick)
				end
			else
				VH:SendToUser ("<" .. VH.HubSec .. "> Unknown command parameter.|", nick)
			end
		else
			VH:SendToUser ("<" .. VH.HubSec .. "> You don't have access to this command.|", nick)
		end

		return 0
	elseif tonumber (flagop) == 0 then
		return checkgag (nick, data)
	end

	return 1
end

function VH_OnParsedMsgChat (nick, data)
	return checkgag (nick, data)
end

function VH_OnParsedMsgPM (nick, data, to)
	return checkgag (nick, data, to)
end

function checkgag (nick, data, to)
	local _, class = VH:GetUserClass (nick)

	if class <= conf.gag then
		local _, code = VH:GetUserCC (nick)
		local _, addr = VH:GetUserIP (nick)

		for _, cc in pairs (gags.code) do
			if code == cc then
				if to then
					VH:SendToUser ("$To: " .. nick .. " From: " .. to .. " $<" .. VH.HubSec .. "> Your message has been blocked.|", nick)
					VH:SendPMToAll ("Country gag from " .. addr .. "." .. code .. " in PM: <" .. nick .. "> " .. data, VH.OpChat, conf.feed, 10)
				else
					VH:SendToUser ("<" .. VH.HubSec .. "> Your message has been blocked.|", nick)
					VH:SendPMToAll ("Country gag from " .. addr .. "." .. code .. " in chat: <" .. nick .. "> " .. data, VH.OpChat, conf.feed, 10)
				end

				return 0
			end
		end

		local addrnum = addrtonum (addr)

		for _, range in pairs (gags.range) do
			local _, _, rangemin, rangemax = range:find ("^(%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?)%-(%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?)$")

			if rangemin and rangemax then
				rangemin = addrtonum (rangemin)
				rangemax = addrtonum (rangemax)

				if rangemin > 0 and rangemax > 0 and addrnum >= rangemin and addrnum <= rangemax then
					if to then
						VH:SendToUser ("$To: " .. nick .. " From: " .. to .. " $<" .. VH.HubSec .. "> Your message has been blocked.|", nick)
						VH:SendPMToAll ("Range gag from " .. addr .. "." .. code .. " in PM: <" .. nick .. "> " .. data, VH.OpChat, conf.feed, 10)
					else
						VH:SendToUser ("<" .. VH.HubSec .. "> Your message has been blocked.|", nick)
						VH:SendPMToAll ("Range gag from " .. addr .. "." .. code .. " in chat: <" .. nick .. "> " .. data, VH.OpChat, conf.feed, 10)
					end

					return 0
				end
			end
		end
	end

	return 1
end

function addrtonum (addr)
	local _, _, numa, numb, numc, numd = addr:find ("^(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)$")

	if numa and numb and numc and numd then
		return 2 ^ 24 * tonumber (numa) + 2 ^ 16 * tonumber (numb) + 2 ^ 8 * tonumber (numc) + tonumber (numd)
	else
		return 0
	end
end

function sqlchars (data)
	local sql = data
	sql = sql:gsub (string.char (92), string.char (92, 92))
	sql = sql:gsub (string.char (34), string.char (92, 34))
	sql = sql:gsub (string.char (39), string.char (92, 39))
	return sql
end

-- end of file