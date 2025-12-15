-- Verlihub Connection Debugger 0.4.0.0
-- Â© 2012-2021 RoLex

conf = {
	feed = "DBG",
	clas = 10,
	conn = false
}

function Main (file)
	if # conf.feed == 0 then
		conf.feed = VH.OpChat
	end

	return 1
end

function VH_OnNewConn (cddr, cort, sddr, sort)
	if conf.conn then
		local _, code = VH:GetIPCC (cddr)
		feed (string.format ("Connect from: %s.%s", cddr, code or "??"))
	end

	return 1
end

function VH_OnParsedMsgValidateNick (nick, addr)
	if conf.conn then
		local _, code = VH:GetIPCC (addr)
		feed (string.format ("Nick from %s.%s: %s", addr, code or "??", nmdc (nick:sub (15))))
	end

	return 1
end

function VH_OnUserLogin (nick, addr)
	if conf.conn then
		local _, code = VH:GetUserCC (nick)
		feed (string.format ("Login from %s.%s: %s", addr or "127.0.0.1", code or "??", nick))
	end

	return 1
end

function VH_OnUserLogout (nick, addr)
	if conf.conn then
		local _, code = VH:GetUserCC (nick)
		feed (string.format ("Logout from %s.%s: %s", addr or "127.0.0.1", code or "??", nick))
	end

	return 1
end

function VH_OnCloseConnEx (addr, code, nick)
	local num, info = tonumber (code or 0) or 0, ""

	if num == 0 then info = "eCR_DEFAULT"
	elseif num == 1 then info = "eCR_INVALID_USER"
	elseif num == 2 then info = "eCR_KICKED"
	elseif num == 3 then info = "eCR_FORCEMOVE"
	elseif num == 4 then info = "eCR_QUIT"
	elseif num == 5 then info = "eCR_HUB_LOAD"
	elseif num == 6 then info = "eCR_TIMEOUT"
	elseif num == 7 then info = "eCR_TO_ANYACTION"
	elseif num == 8 then info = "eCR_USERLIMIT"
	elseif num == 9 then info = "eCR_SHARE_LIMIT"
	elseif num == 10 then info = "eCR_TAG_NONE"
	elseif num == 11 then info = "eCR_TAG_INVALID"
	elseif num == 12 then info = "eCR_PASSWORD"
	elseif num == 13 then info = "eCR_LOGIN_ERR"
	elseif num == 14 then info = "eCR_SYNTAX"
	elseif num == 15 then info = "eCR_INVALID_KEY"
	elseif num == 16 then info = "eCR_RECONNECT"
	elseif num == 17 then info = "eCR_CLONE"
	elseif num == 18 then info = "eCR_SELF"
	elseif num == 19 then info = "eCR_BADNICK"
	elseif num == 20 then info = "eCR_NOREDIR"
	elseif num == 21 then info = "eCR_PLUGIN"
	else
		info = string.format ("unexpected code %d", num)
	end

	local _, code = VH:GetIPCC (addr)
	feed (string.format ("Disconnect due to %s from %s.%s: %s", info, addr, code or "??", nick or "<unknown nick>"))
	return 1
end

function feed (data)
	VH:SendPMToAll (data, conf.feed, conf.clas, 10)

	if conf.feed == VH.OpChat then
		VH:ScriptCommand ("opchat_to_all", "[" .. _tostring (conf.clas) .. "] <" .. conf.feed .. "> " .. data) -- to catch in ledokol
	end
end

function nmdc (data)
	local safe = data
	safe = safe:gsub ("%$", "&#36;")
	safe = safe:gsub ("|", "&#124;")
	return safe
end

function _tostring (val)
	if type (val) == "number" then
		return string.format ("%d", val)
	end

	return tostring (val)
end

-- end of file