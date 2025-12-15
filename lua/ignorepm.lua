-- Ignore PM 0.1.2.2
-- © 2013-2020 RoLex

config = {
	use = 2,
	set = 5
}

function Main (script)
	VH:SQLQuery ("create table if not exists `lua_ignorepm` (`to` varchar(255) not null, `from` varchar(255) not null)")
	return 1
end

function VH_OnHubCommand (nick, data, op, pm)
	local _, class = VH:GetUserClass (nick)

	if data:find ("^.ig %S+$") and class >= config.use then
		local _, _, from = data:find ("^.ig (%S+)$")
		local _, rows = VH:SQLQuery ("select `to` from `lua_ignorepm` where `to` = '" .. sqlchars (nick) .. "' and `from` = '" .. sqlchars (from) .. "'")

		if rows == 0 then
			VH:SQLQuery ("insert into `lua_ignorepm` (`to`, `from`) values ('" .. sqlchars (nick) .. "', '" .. sqlchars (from) .. "')")
			reply (nick, "Item added to your ignore list: " .. from, pm)
		else
			reply (nick, "Item already in your ignore list: " .. from, pm)
		end

		return 0

	elseif data:find ("^.unig %S+$") and class >= config.use then
		local _, _, from = data:find ("^.unig (%S+)$")
		local _, rows = VH:SQLQuery ("select `to` from `lua_ignorepm` where `to` = '" .. sqlchars (nick) .. "' and `from` = '" .. sqlchars (from) .. "'")

		if rows == 1 then
			VH:SQLQuery ("delete from `lua_ignorepm` where `to` = '" .. sqlchars (nick) .. "' and `from` = '" .. sqlchars (from) .. "'")
			reply (nick, "Item removed from your ignore list: " .. from, pm)
		else
			reply (nick, "Item is not in your ignore list: " .. from, pm)
		end

		return 0

	elseif data:find ("^.myig$") and class >= config.use then
		local _, rows = VH:SQLQuery ("select `from` from `lua_ignorepm` where `to` = '" .. sqlchars (nick) .. "' order by `from` asc")

		if rows > 0 then
			local list = ""

			for x = 0, rows - 1 do
				local _, from = VH:SQLFetch (x)
				list = list .. " " .. _tostring (x + 1) .. ". " .. from .. "\r\n"
			end

			reply (nick, "Items in your ignore list:\r\n\r\n" .. list, pm)
		else
			reply (nick, "Your ignore list is out of items.", pm)
		end

		return 0

	elseif data:find ("^.igadd %S+ %S+$") and class >= config.set then
		local _, _, to, from = data:find ("^.igadd (%S+) (%S+)$")
		local _, rows = VH:SQLQuery ("select `to` from `lua_ignorepm` where `to` = '" .. sqlchars (to) .. "' and `from` = '" .. sqlchars (from) .. "'")

		if rows == 0 then
			VH:SQLQuery ("insert into `lua_ignorepm` (`to`, `from`) values ('" .. sqlchars (to) .. "', '" .. sqlchars (from) .. "')")
			reply (nick, "Item added to ignore list: " .. to .. " < " .. from, pm)
		else
			reply (nick, "Item already in ignore list: " .. to .. " < " .. from, pm)
		end

		return 0

	elseif data:find ("^.igdel %S+ %S+$") and class >= config.set then
		local _, _, to, from = data:find ("^.igdel (%S+) (%S+)$")
		local _, rows = VH:SQLQuery ("select `to` from `lua_ignorepm` where `to` = '" .. sqlchars (to) .. "' and `from` = '" .. sqlchars (from) .. "'")

		if rows == 1 then
			VH:SQLQuery ("delete from `lua_ignorepm` where `to` = '" .. sqlchars (to) .. "' and `from` = '" .. sqlchars (from) .. "'")
			reply (nick, "Item removed from ignore list: " .. to .. " < " .. from, pm)
		else
			reply (nick, "Item is not in ignore list: " .. to .. " < " .. from, pm)
		end

		return 0

	elseif data:find ("^.iglist$") and class >= config.set then
		local _, rows = VH:SQLQuery ("select `to`, `from` from `lua_ignorepm` order by `to` asc")

		if rows > 0 then
			local list = ""

			for x = 0, rows - 1 do
				local _, to, from = VH:SQLFetch (x)
				list = list .. " " .. _tostring (x + 1) .. ". " .. to .. " < " .. from .. "\r\n"
			end

			reply (nick, "Items in ignore list:\r\n\r\n" .. list, pm)
		else
			reply (nick, "Ignore list is out of items.", pm)
		end

		return 0
	end

	return 1
end

function VH_OnParsedMsgPM (from, data, to)
	local _, class = VH:GetUserClass (from)

	if class < config.set then
		local _, rows = VH:SQLQuery ("select `to` from `lua_ignorepm` where `to` = '" .. sqlchars (to) .. "' and `from` = '" .. sqlchars (from) .. "'")

		if rows == 1 then
			VH:SendToUser ("$To: " .. from .. " From: " .. to .. " $<" .. VH.HubSec .. "> Your messages to this user are ignored.|", from)
			return 0
		end
	end

	return 1
end

function reply (nick, data, pm)
	if tonumber (pm) == 1 then
		VH:SendToUser ("$To: " .. nick .. " From: " .. VH.HubSec .. " $<" .. VH.HubSec .. "> " .. data .. "|", nick)
	else
		VH:SendToUser ("<" .. VH.HubSec .. "> " .. data .. "|", nick)
	end
end

function sqlchars (data)
	local out = data:gsub (string.char (92), string.char (92, 92))
	out = out:gsub (string.char (34), string.char (92, 34))
	return out:gsub (string.char (39), string.char (92, 39))
end

function _tostring (val)
	if type (val) == "number" then
		return string.format ("%d", val)
	end

	return tostring (val)
end

-- end of file