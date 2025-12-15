-- CitatyInfo 0.0.1.2
-- © 2022-2023 RoLex

conf = {
	user = 0,											-- minimum class to use quotes
	auto = 60,											-- automatic quote time in minutes
	wait = 30,											-- command wait time in seconds
	nick = "",											-- message send nick or hub default
	comm = "+quote",									-- manual quote command name
	hist = false,										-- save in ledokol history
	file = "citaty",									-- temporary file name
	path = "",											-- download path or hub default
	lang = "ru",										-- translation language or english
	tran = {
		en = {											-- english translation
			quot = "Random quote from citaty.info:",
			user = "Command access is restricted.",
			late = "Please try again later.",
			wait = "Please wait %d seconds.",
			code = "They changed source code again.",
			read = "Failed to read temporary file.",
			open = "Failed to open temporary file.",
			conv = "Failed to execute iconv command.",
			curl = "Failed to execute curl command."
		},
		ru = {											-- russian translation
			quot = "Ñëó÷àéíàÿ öèòàòà ñ citaty.info:",
			user = "Äîñòóï ê êîìàíäå îãðàíè÷åí.",
			late = "Ïîæàëóéñòà ïîïðîáóéòå ïîçæå.",
			wait = "Ïîæàëóéñòà ïîäîæäèòå %d ñåêóíä.",
			code = "Îíè îïÿòü èçìåíèëè èñõîäíûé êîä.",
			read = "Íå óäàëîñü ïðî÷åñòü âðåìåííûé ôàéë.",
			open = "Íå óäàëîñü îòêðûòü âðåìåííûé ôàéë.",
			conv = "Íå óäàëîñü âûïîëíèòü êîìàíäó iconv.",
			curl = "Íå óäàëîñü âûïîëíèòü êîìàíäó curl."
		}
	}
}

last = {
	auto = 0,
	wait = 0
}

function Main (file)
	if # conf.path == 0 then
		local _, path = VH:GetVHCfgDir ()
		conf.path = path
	end

	if conf.tran [conf.lang] then
		conf.lang = conf.tran [conf.lang]
	else
		conf.lang = conf.tran.en
	end

	return 1
end

function VH_OnTimer (msec)
	if conf.auto > 0 and os.difftime (os.time (), last.auto) >= conf.auto * 60 then
		quote ()
	end

	return 1
end

function VH_OnHubCommand (nick, data, op, pm)
	if data == conf.comm then
		local _, user = VH:GetUserClass (nick)

		if user >= conf.user then
			local diff = os.difftime (os.time (), last.wait)

			if diff >= conf.wait then
				if not quote () then
					toone (conf.lang.late, nick)
				else
					last.wait = os.time ()
				end

			else
				toone (conf.lang.wait:format (conf.wait - diff), nick)
			end

		else
			toone (conf.lang.user, nick)
		end

		return 0
	end

	return 1
end

function quote ()
	local res = false

	if os.execute ("curl --get --location --max-redirs 1 --retry 2 --connect-timeout 5 --max-time 10 --user-agent \"Mozilla/5.0 (compatible; CitatyInfo/0.0.1.2; +https://ledo.feardc.net/other/)\" --silent --output \"" .. conf.path .. "/" .. conf.file .. ".curl\" \"https://citaty.info/random/\"") then
		local file = io.open (conf.path .. "/" .. conf.file .. ".curl", "r")

		if file then
			file:close ()

			if os.execute ("iconv -s -c -f \"UTF-8\" -t \"CP1251\" -o \"" .. conf.path .. "/" .. conf.file .. ".conv\" \"" .. conf.path .. "/" .. conf.file .. ".curl\"") then
				local file = io.open (conf.path .. "/" .. conf.file .. ".conv", "r")

				if file then
					local data = file:read ("*all")
					file:close ()
					os.remove (conf.path .. "/" .. conf.file .. ".conv")

					if data and # data > 0 then
						local quot = data:match ("<div class=\"field%-item even last\"><p>(.-)</p></div>")

						if quot and # quot > 0 then
							quot = quot:gsub ("<a[^>]*>", "")
							quot = quot:gsub ("</a>", "")
							quot = quot:gsub ("</p>", "\r\n\r\n")
							quot = quot:gsub ("<p>", "")
							quot = quot:gsub ("<br[^>]*>", "\r\n")
							quot = quot:gsub ("&lt;", "<")
							quot = quot:gsub ("&gt;", ">")
							quot = quot:gsub ("&#60;", "<")
							quot = quot:gsub ("&#62;", ">")
							quot = quot:gsub ("&quot;", "\"")
							quot = quot:gsub ("&#39;", "'")
							quot = quot:gsub ("&nbsp;", " ")
							quot = quot:gsub ("&amp;", "&")
							quot = quot:gsub ("&mdash;", "-")
							quot = quot:gsub ("^[\r\n ]+", "")
							quot = quot:gsub ("[\r\n ]+$", "")
							quot = quot:gsub (" *\r\n *", "\r\n ")

							if # quot > 0 then
								toall (conf.lang.quot .. "\r\n\r\n " .. quot .. "\r\n")
								res = true
							end

						else
							toall (conf.lang.code)
							res = true
						end

					else
						toall (conf.lang.read)
					end

				else
					toall (conf.lang.open)
				end

			else
				toall (conf.lang.conv)
			end

			os.remove (conf.path .. "/" .. conf.file .. ".curl")

		else
			toall (conf.lang.open)
		end

	else
		toall (conf.lang.curl)
	end

	last.auto = os.time ()
	return res
end

function toone (data, nick)
	VH:SendToUser ("<" .. ((# conf.nick ~= 0 and conf.nick) or VH.HubSec) .. "> " .. nmdc (data) .. "|", nick)
end

function toall (data)
	VH:SendToChat (((# conf.nick ~= 0 and conf.nick) or VH.HubSec), nmdc (data), conf.user, 10)

	if conf.hist then
		VH:ScriptCommand ("chat_to_all", "<" .. ((# conf.nick ~= 0 and conf.nick) or VH.HubSec) .. "> " .. data)
	end
end

function nmdc (data)
	local back = data
	back = back:gsub ("|", "&#124;")
	back = back:gsub ("%$", "&#36;")
	return back
end

-- end of file