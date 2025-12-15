-- ShoutCast 0.0.2.1
-- © 2017-2020 RoLex

conf = {
	nick = "",								-- sender nick or hub bot
	from = 0,								-- minimum receive class
	wait = 60,								-- delay time in seconds
	serv = "http://chatonhub.be:8000",		-- full server address
	chat = "Now playing: <name> @ <serv>",	-- chat message format: <name>, <serv>, <cur>, <peak>, <max>, <uni>, <bit>
	temp = "./shoutcast.temp",				-- temporary file location
	tick = os.time ()						-- dont change this
}

function VH_OnTimer (msec)
	if os.difftime (os.time (), conf.tick) >= conf.wait then
		if os.execute ("curl -G -L --retry 3 --connect-timeout 5 -m 30 -A \"Mozilla/5.0\" -s -o \"" .. conf.temp .. "\" \"" .. conf.serv .. "/7\"") then
			local file = io.open (conf.temp, "r")

			if file then
				local data = file:read ("*all")
				file:close ()
				os.remove (conf.temp)

				if data and # data > 0 then
					local cur, on, peak, max, uni, bit, name = data:match ("<body>(%d*),(%d*),(%d*),(%d*),(%d*),(%d*),(.*)</body>")

					if on and tonumber (on) == 1 then
						local chat = conf.chat

						if cur then
							chat = chat:gsub ("<cur>", _tostring (cur))
						end

						if peak then
							chat = chat:gsub ("<peak>", _tostring (peak))
						end

						if max then
							chat = chat:gsub ("<max>", _tostring (max))
						end

						if uni then
							chat = chat:gsub ("<uni>", _tostring (uni))
						end

						if bit then
							chat = chat:gsub ("<bit>", _tostring (bit))
						end

						if name then
							chat = chat:gsub ("<name>", nmdcdata (name))
						end

						chat = chat:gsub ("<serv>", nmdcdata (conf.serv))
						VH:SendToClass ("<" .. ((# conf.nick > 0 and conf.nick) or VH.HubSec) .. "> " .. chat .. "|", conf.from, 10)
					end
				end
			end
		end

		conf.tick = os.time ()
	end

	return 1
end

function nmdcdata (data)
	local safe = data
	safe = safe:gsub ("|", "&#124;")
	safe = safe:gsub ("%$", "&#36;")
	return safe
end

function _tostring (val)
	if type (val) == "number" then
		return string.format ("%d", val)
	end

	return tostring (val)
end

-- end of file