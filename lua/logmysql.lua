-- MySQL Log 0.0.1.1
-- Â© 2018-2020 RoLex
-- Thanks to HackFresse

--[[

	Folowing privileges must be applied to mysql table and session restarted before using:

		> grant super, drop, select on *.* to 'verlihub'@'localhost'

]]--

function VH_OnHubCommand (nick, data, op, pm)
	local _, class = VH:GetUserClass (nick)

	if class == 10 then
		if data:sub (2, 8) == "mylogon" then
			VH:SQLQuery ("set global general_log = 1")
			VH:SQLQuery ("set global log_output = 'table'")
			VH:SendToUser ("<" .. VH.HubSec .. "> MySQL log enabled.|", nick)
			return 0

		elseif data:sub (2, 9) == "mylogoff" then
			VH:SQLQuery ("set global general_log = 0")
			VH:SendToUser ("<" .. VH.HubSec .. "> MySQL log disabled.|", nick)
			return 0

		elseif data:sub (2, 9) == "mylogdel" then
			VH:SQLQuery ("truncate `mysql`.`general_log`")
			VH:SendToUser ("<" .. VH.HubSec .. "> MySQL logs deleted.|", nick)
			return 0

		elseif data:sub (2, 10) == "mylogshow" then
			VH:SQLQuery ("select connection_id()")
			local _, id = VH:SQLFetch (0)
			id = tonumber (id or 0) or 0

			if id > 0 then
				local lim = data:sub (12)
				lim = tonumber (lim or 100) or 100
				local _, rows = VH:SQLQuery ("select `event_time`, `argument` from `mysql`.`general_log` where `thread_id` = " .. _tostring (id) .. " and `command_type` = 'Query' order by `event_time` desc limit " .. _tostring (lim))

				if rows > 0 then
					local list = ""

					for row = 0, rows - 1 do
						local _, sta, arg = VH:SQLFetch (row)
						list = list .. " " .. _tostring (row + 1) .. ". " .. specs (sta:sub (12)) .. " > " .. specs (arg) .. "\r\n"
					end

					VH:SendToUser ("<" .. VH.HubSec .. "> MySQL log:\r\n\r\n" .. list .. "|", nick)
				else
					VH:SendToUser ("<" .. VH.HubSec .. "> Nothing to show.|", nick)
				end

			else
				VH:SendToUser ("<" .. VH.HubSec .. "> Missing connection ID.|", nick)
			end

			return 0
		end
	end

	return 1
end

function _tostring (data)
	if type (data) == "number" then
		return string.format ("%d", data)
	end

	return tostring (data)
end

function specs (data)
	local safe = _tostring (data)
	safe = safe:gsub ("%$", "&#36;")
	safe = safe:gsub ("|", "&#124;")
	return safe
end

-- end of file