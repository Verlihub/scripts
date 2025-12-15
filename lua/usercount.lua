-- User Count 0.2.1.1
-- © 2016-2020 RoLex

conf = {
	verb = true
}

function VH_OnHubCommand (nick, data, op, pm)
	local _, clas = VH:GetUserClass (nick)

	if tonumber (clas) < 10 or data:sub (2, 3) ~= "uc" then
		return 1
	end

	local func, part = data:sub (5, 7), data:sub (9)

	if # func == 0 or # part == 0 then
		VH:SendToUser ("<" .. VH.HubSec .. "> Missing command parameters.|", nick)
		return 0
	end

	part = nmdcchar (part)
	local coun, unit, line, cond = 0, 1, "", (part:sub (1, 1) == "!")

	if cond then
		part = part:sub (2)
		unit = -unit
	end

	if func == "sup" then
		local _, list = VH:GetNickList ()

		for user in list:sub (11):gmatch ("[^%$ ]+") do
			local _, sups = VH:GetUserSupports (user)

			if sups and # sups > 0 then
				if cond == (sups:match (part) == nil) then
					coun = coun + unit

					if conf.verb then
						if line == "" then
							line = "\r\n\r\n"
						end

						line = line .. " " .. _tostring (coun) .. ". " .. user .. " > " .. sups .. "\r\n"
					end
				end
			end
		end

		VH:SendToUser ("<" .. VH.HubSec .. "> Supports user count: " .. _tostring (coun) .. line .. "|", nick)
		return 0
	end

	VH:SendToUser ("<" .. VH.HubSec .. "> Unknown count function.|", nick)
	return 0
end

function nmdcchar (data, out)
	local back = data

	if out then
		back = back:gsub ("%$", "&#36;")
		back = back:gsub ("|", "&#124;")
	else
		back = back:gsub ("&amp;", "&") -- todo: not sure about it
		back = back:gsub ("&#36;", "$")
		back = back:gsub ("&#124;", "|")
	end

	return back
end

function _tostring (val)
	if type (val) == "number" then
		return string.format ("%d", val)
	end

	return tostring (val)
end

-- end of file