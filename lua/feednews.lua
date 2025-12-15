-- Feed News 0.8.5.1
-- © 2014-2023 RoLex

conf = {
	wait = 120, -- time in minutes
	show = 8, -- items per feed
	user = 0, -- minimum send class
	warn = 10, -- minimum warn class
	hist = 0, -- use ledokol history
	info = 0, -- show debug information
	nick = "", -- sender nick or hub default
	char = "" -- character encoding or hub default
}

link = { -- feed link list
	--[[
	["RIA"] = "https://ria.ru/export/rss2/archive/index.xml",
	["Rambler"] = "https://news.rambler.ru/rss/head/",
	["Rambler"] = "https://news.rambler.ru/rss/world/"
	]]--
}

cuts = {} -- url cut out list
skip = {} -- partial skip list

lang = { -- translation list
	news = "Latest news:\r\n",								-- message header
	head = "\r\n « <head> »",								-- news item header
	desc = "\r\n <auth>: <desc>",							-- item description
	more = "\r\n Read more: <more>\r\n",					-- read more link
	curl = "Failed to execute curl command for: <name>",	-- curl execute warning
	conv = "Failed to execute iconv command for: <name>",	-- iconv execute warning
	open = "Failed to open temporary file for: <name>",		-- file open warning
	read = "Failed to read temporary file for: <name>",		-- file read warning
	find = "Failed to find all information for: <name>",	-- data find warning
	item = "Failed to find any news items for: <name>",		-- news find warning
	deco = "Conversion of news text: <fcon> -> <tcon>"		-- conversion debug
	--[[
	news = "Ïîñëåäíèå íîâîñòè:\r\n",
	head = "\r\n « <head> »",
	desc = "\r\n <auth>: <desc>",
	more = "\r\n Ïîäðîáíåå: <more>\r\n",
	curl = "Íå óäàëîñü âûïîëíèòü êîìàíäó curl äëÿ: <name>",
	conv = "Íå óäàëîñü âûïîëíèòü êîìàíäó iconv äëÿ: <name>",
	open = "Íå óäàëîñü îòêðûòü âðåìåííûé ôàéë äëÿ: <name>",
	read = "Íå óäàëîñü ïðî÷åñòü âðåìåííûé ôàéë äëÿ: <name>",
	find = "Íå óäàëîñü íàéòè âñåé èíôîðìàöèè äëÿ: <name>",
	item = "Íå óäàëîñü íàéòè íè îäíîé íîâîñòè äëÿ: <name>",
	deco = "Ïðåîáðàçîâàíèå òåêñòà íîâîñòåé: <fcon> -> <tcon>"
	]]--
}

proc = {
	last = 0,
	file = ""
}

function Main (file)
	VH:SQLQuery ("create table if not exists `lua_feednews_conf` (`name` varchar(255) not null primary key, `value` varchar(255) not null)")

	for name, val in pairs (conf) do
		VH:SQLQuery ("insert ignore into `lua_feednews_conf` (`name`, `value`) values ('" .. name .. "', '" .. sql (val) .. "')")
	end

	local _, rows = VH:SQLQuery ("select `name`, `value` from `lua_feednews_conf`")

	for pos = 0, rows - 1 do
		local _, name, val = VH:SQLFetch (pos)

		if conf [name] then
			conf [name] = tonumber (val) or val
		end
	end

	if # conf.nick == 0 then
		conf.nick = VH.HubSec
	end

	if # conf.char == 0 then
		local _, val = VH:GetConfig (VH.ConfName, "hub_encoding")
		conf.char = val:upper ()
	end

	VH:SQLQuery ("create table if not exists `lua_feednews_link` (`name` varchar(255) not null primary key, `link` varchar(255) not null unique, `off` tinyint(1) unsigned not null default 0)")
	local _, rows = VH:SQLQuery ("select `name`, `link` from `lua_feednews_link` where `off` = 0")

	for pos = 0, rows - 1 do
		local _, name, val = VH:SQLFetch (pos)
		link [name] = val
	end

	VH:SQLQuery ("create table if not exists `lua_feednews_cuts` (`part` varchar(255) not null primary key, `off` tinyint(1) unsigned not null default 0)")
	local _, rows = VH:SQLQuery ("select `part` from `lua_feednews_cuts` where `off` = 0")

	for pos = 0, rows - 1 do
		local _, val = VH:SQLFetch (pos)
		table.insert (cuts, val)
	end

	VH:SQLQuery ("create table if not exists `lua_feednews_skip` (`part` varchar(255) not null primary key, `off` tinyint(1) unsigned not null default 0)")
	local _, rows = VH:SQLQuery ("select `part` from `lua_feednews_skip` where `off` = 0")

	for pos = 0, rows - 1 do
		local _, val = VH:SQLFetch (pos)
		table.insert (skip, val)
	end

	VH:SQLQuery ("create table if not exists `lua_feednews_lang` (`name` varchar(255) not null primary key, `value` varchar(255) not null)")

	for name, val in pairs (lang) do
		val = val:gsub ("\r", "\\r")
		val = val:gsub ("\n", "\\n")
		val = val:gsub ("\t", "\\t")
		VH:SQLQuery ("insert ignore into `lua_feednews_lang` (`name`, `value`) values ('" .. name .. "', '" .. sql (val) .. "')")
	end

	local _, rows = VH:SQLQuery ("select `name`, `value` from `lua_feednews_lang`")

	for pos = 0, rows - 1 do
		local _, name, val = VH:SQLFetch (pos)

		if lang [name] then
			val = val:gsub ("\\r", "\r")
			val = val:gsub ("\\n", "\n")
			val = val:gsub ("\\t", "\t")
			lang [name] = val
		end
	end

	local _, val = VH:GetVHCfgDir ()
	proc.file = val .. "/feednews"
	math.randomseed (os.time ())
	return 1
end

function VH_OnTimer (msec)
	if os.difftime (os.time (), proc.last) < conf.wait * 60 then
		return 1
	end

	local news = {}

	for name, url in pairs (link) do
		if os.execute ("curl --get --location --max-redirs 1 --retry 2 --connect-timeout 5 --max-time 15 --user-agent \"Mozilla/5.0 (compatible; FeedNews/0.8.5.0; +https://ledo.feardc.net/other/)\" --silent --output \"" .. proc.file .. ".curl\" \"" .. url .. "\"") then
			local file = io.open (proc.file .. ".curl", "r")

			if file then
				local data = file:read ("*all")
				file:close ()

				if data and # data > 0 then
					if # conf.char > 0 then
						local chat = data:match ("<%?xml.- encoding=\"(.-)\".-%?>")

						if chat and # chat > 0 then
							chat = chat:upper ()

							if chat ~= conf.char then
								if conf.info == 1 then
									send (lang.deco, conf.warn, name, url, nil, nil, nil, nil, chat, conf.char)
								end

								if os.execute ("iconv -s -c -f \"" .. chat .. "\" -t \"" .. conf.char .. "\" -o \"" .. proc.file .. ".conv\" \"" .. proc.file .. ".curl\"") then
									local file = io.open (proc.file .. ".conv", "r")

									if file then
										local conv = file:read ("*all")
										file:close ()

										if conv and # conv > 0 then
											data = conv
										else -- read error
											send (lang.read, conf.warn, name, url)
										end

									else -- open error
										send (lang.open, conf.warn, name, url)
									end

								else -- convert error
									send (lang.conv, conf.warn, name, url)
								end

								os.remove (proc.file .. ".conv")
							end
						end
					end

					local size = 0

					for item in data:gmatch ("<item[^>]*>(.-)</item>") do
						local head, desc, more, auth = item:match ("<title>(.-)</title>"), item:match ("<description>(.-)</description>"), item:match ("<link>(.-)</link>"), item:match ("<author>(.-)</author>")
						local perm, guid = item:match ("<guid(.-)>(.-)</guid>")

						if head and desc and (guid or more) then
							if # head > 0 then -- title
								head = head:gsub ("\r", " ")
								head = head:gsub ("\n", " ")
								head = head:gsub (" +", " ")
								head = head:gsub ("^ +", "")
								head = head:gsub (" +$", "")
							end

							if # desc > 0 then -- description
								desc = desc:gsub ("<!%[CDATA%[", " ")
								desc = desc:gsub ("%]%]>", " ")
								desc = desc:gsub ("<.-/>", " ")
								desc = desc:gsub ("<.->.-</.->", " ")
								desc = desc:gsub ("<.->", " ")
								desc = desc:gsub ("\r", " ")
								desc = desc:gsub ("\n", " ")
								desc = desc:gsub (" +", " ")
								desc = desc:gsub ("^ +", "")
								desc = desc:gsub (" +$", "")
							end

							if guid and # guid > 0 then -- guid
								if perm and # perm > 0 then
									perm = perm:gsub (" ", "")
									perm = perm:gsub ("'", "\"")

									if perm:lower () == "ispermalink=\"false\"" then
										guid = ""
									end
								end

								if # guid > 0 then
									more = guid
								end
							end

							if more and # more > 0 then -- link
								more = more:gsub ("\r", "")
								more = more:gsub ("\n", "")
								more = more:gsub (" ", "")
							end

							if auth and # auth > 0 then -- author
								auth = auth:gsub ("\r", "")
								auth = auth:gsub ("\n", "")
								auth = auth:gsub (" +", " ")
								auth = auth:gsub ("^ +", "")
								auth = auth:gsub (" +$", "")

							else
								auth = ""
							end

							if # auth == 0 then
								auth = name
							end

							if # head > 0 and # desc > 0 and # more > 0 then
								local keep = true

								for _, part in pairs (skip) do
									if head:find (part, 1, true) or desc:find (part, 1, true) or more:find (part, 1, true) then
										keep = false
										break
									end
								end

								if keep then
									if # cuts > 0 then
										for _, part in pairs (cuts) do
											if more:match (part) then
												more = more:gsub (part, "")
												--keep = false
											end
										end

										--if # more > 0 and not keep then
										if # more > 0 and not more:match ("^http://") and not more:match ("^https://") then
											--more = "http://" .. decode (more)
											more = "https://" .. decode (more)
										end
									end

									if # more > 0 then
										size = size + 1

										table.insert (news, {
											n = name,
											l = url,
											h = head,
											d = desc,
											m = more,
											a = auth
										})
									end
								end

							else -- find error
								send (lang.find, conf.warn, name, url, head, desc, more, auth)
							end

						else -- find error
							send (lang.find, conf.warn, name, url, head, desc, more, auth)
						end
					end

					if size == 0 then -- item error
						send (lang.item, conf.warn, name, url)
					end

				else -- read error
					send (lang.read, conf.warn, name, url)
				end

			else -- open error
				send (lang.open, conf.warn, name, url)
			end

		else -- get error
			send (lang.curl, conf.warn, name, url)
		end

		os.remove (proc.file .. ".curl")
	end

	if # news > 0 then
		local list, stop = "", 0
		news = shuffle (news)

		for _, data in pairs (news) do
			stop = stop + 1
			list = list .. variables (lang.head .. lang.desc .. lang.more, data.n, data.l, data.h, data.d, data.m, data.a)

			if stop >= conf.show then
				break
			end
		end

		if # list > 0 then
			send (lang.news .. list, conf.user)

			if conf.hist == 1 then
				VH:ScriptCommand ("chat_to_all", "<" .. conf.nick .. "> " .. lang.news .. list)
			end
		end
	end

	proc.last = os.time ()
	return 1
end

function VH_OnHubCommand (nick, data, op, pm)
	if not data:match ("^.fn") then
		return 1
	end

	local _, clas = VH:GetUserClass (nick)

	if tonumber (clas) < conf.warn then
		VH:SendToUser ("<" .. conf.nick .. "> You have no access.|", nick)
		return 0
	end

	local back = ""

	if data:match ("^.fn conf") then -- conf
		local name, val = data:match ("^.fn conf ([^ ]+) (.*)$")

		if name and val then -- set
			if conf [name] then
				--val = nmdc (val, true)

				if type (conf [name]) == "number" then
					val = tonumber (val)
				end

				if val ~= nil then
					VH:SQLQuery ("update `lua_feednews_conf` set `value` = '" .. sql (val) .. "' where `name` = '" .. name .. "'")
					back = "Configuration updated: " .. name .. " = " .. conf [name] .. " -> " .. val
					conf [name] = val

				else
					back = "Configuration not number: " .. name
				end

			else
				back = "Configuration not found: " .. name
			end

		else -- list
			back = "Configuration list:\r\n\r\n"

			for name, val in pairs (conf) do
				back = back .. " " .. name .. " = " .. val .. "\r\n"
			end
		end

	elseif data:match ("^.fn lang") then -- lang
		local name, val = data:match ("^.fn lang ([^ ]+) (.+)$")

		if name and val then -- set
			if lang [name] then
				local safe, old = nmdc (val, true), lang [name]
				VH:SQLQuery ("update `lua_feednews_lang` set `value` = '" .. sql (safe) .. "' where `name` = '" .. name .. "'")

				old = old:gsub ("\r", "\\r")
				old = old:gsub ("\n", "\\n")
				old = old:gsub ("\t", "\\t")
				back = "Translation updated: " .. name .. " = \"" .. old .. "\" -> \"" .. val .. "\""

				safe = safe:gsub ("\\r", "\r")
				safe = safe:gsub ("\\n", "\n")
				safe = safe:gsub ("\\t", "\t")
				lang [name] = safe

			else
				back = "Translation not found: " .. name
			end

		else -- list
			back = "Translation list:\r\n\r\n"

			for name, val in pairs (lang) do
				val = val:gsub ("\r", "\\r")
				val = val:gsub ("\n", "\\n")
				val = val:gsub ("\t", "\\t")
				back = back .. " " .. name .. " = " .. val .. "\r\n"
			end
		end

	elseif data:match ("^.fn link") then -- link
		local name, val = data:match ("^.fn link ([^ ]+) (.+)$")

		if name == "add" then -- add
			local head, url = val:match ("^([^ ]+) ([^ ]+)$")

			if head and url then
				local _head, _url = nmdc (head, true), nmdc (url, true)
				local _, rows = VH:SQLQuery ("select `name`, `link` from `lua_feednews_link` where `name` = '" .. sql (_head) .. "' or `link` = '" .. sql (_url) .. "'")

				if rows == 0 then
					VH:SQLQuery ("insert into `lua_feednews_link` (`name`, `link`) values ('" .. sql (_head) .. "', '" .. sql (_url) .. "')")
					link [_head] = _url
					back = "Feed link added: " .. head .. " @ " .. url

				else
					local _, _head, _url = VH:SQLFetch (0)
					back = "Feed link already exists: " .. _head .. " @ " .. _url
				end

			else
				back = "Bad command parameters."
			end

		elseif name == "del" then -- del
			local _, rows = VH:SQLQuery ("select `name` from `lua_feednews_link` where `name` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, head = VH:SQLFetch (0)
				VH:SQLQuery ("delete from `lua_feednews_link` where `name` = '" .. sql (head) .. "'")
				link [head] = nil
				back = "Feed link deleted: " .. head

			else
				back = "Feed link not found: " .. val
			end

		elseif name == "off" then -- off
			local _, rows = VH:SQLQuery ("select `name`, `off` from `lua_feednews_link` where `name` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, head, off = VH:SQLFetch (0)

				if tonumber (off) == 0 then
					VH:SQLQuery ("update `lua_feednews_link` set `off` = 1 where `name` = '" .. sql (head) .. "'")
					link [head] = nil
					back = "Feed link disabled: " .. head

				else
					back = "Feed link already disabled: " .. head
				end

			else
				back = "Feed link not found: " .. val
			end

		elseif name == "on" then -- on
			local _, rows = VH:SQLQuery ("select `name`, `link`, `off` from `lua_feednews_link` where `name` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, head, url, off = VH:SQLFetch (0)

				if tonumber (off) == 1 then
					VH:SQLQuery ("update `lua_feednews_link` set `off` = 0 where `name` = '" .. sql (head) .. "'")
					link [head] = url
					back = "Feed link enabled: " .. head

				else
					back = "Feed link already enabled: " .. head
				end

			else
				back = "Feed link not found: " .. val
			end

		else -- list
			local _, rows = VH:SQLQuery ("select `name`, `link`, `off` from `lua_feednews_link`")

			if rows > 0 then
				back = "Feed link list:\r\n\r\n"

				for pos = 0, rows - 1 do
					local _, head, url, off = VH:SQLFetch (pos)
					back = back .. " " .. head .. " @ " .. url .. " [" .. (tonumber (off) == 1 and "OFF" or "ON") .. "]\r\n"
				end

			else
				back = "Feed link list is empty."
			end
		end

	elseif data:match ("^.fn cuts") then -- cuts
		local name, val = data:match ("^.fn cuts ([^ ]+) (.+)$")

		if name == "add" then -- add
			local safe = nmdc (val, true)
			local _, rows = VH:SQLQuery ("select `part` from `lua_feednews_cuts` where `part` = '" .. sql (safe) .. "'")

			if rows == 0 then
				VH:SQLQuery ("insert into `lua_feednews_cuts` (`part`) values ('" .. sql (safe) .. "')")
				table.insert (cuts, safe)
				back = "URL cut added: " .. val

			else
				local _, part = VH:SQLFetch (0)
				back = "URL cut already exists: " .. part
			end

		elseif name == "del" then -- del
			local _, rows = VH:SQLQuery ("select `part` from `lua_feednews_cuts` where `part` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, part = VH:SQLFetch (0)
				VH:SQLQuery ("delete from `lua_feednews_cuts` where `part` = '" .. sql (part) .. "'")

				for pos, comp in pairs (cuts) do
					if part == comp then
						table.remove (cuts, pos)
						break
					end
				end

				back = "URL cut deleted: " .. part

			else
				back = "URL cut not found: " .. val
			end

		elseif name == "off" then -- off
			local _, rows = VH:SQLQuery ("select `part`, `off` from `lua_feednews_cuts` where `part` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, part, off = VH:SQLFetch (0)

				if tonumber (off) == 0 then
					VH:SQLQuery ("update `lua_feednews_cuts` set `off` = 1 where `part` = '" .. sql (part) .. "'")

					for pos, comp in pairs (cuts) do
						if part == comp then
							table.remove (cuts, pos)
							break
						end
					end

					back = "URL cut disabled: " .. part

				else
					back = "URL cut already disabled: " .. part
				end

			else
				back = "URL cut not found: " .. val
			end

		elseif name == "on" then -- on
			local _, rows = VH:SQLQuery ("select `part`, `off` from `lua_feednews_cuts` where `part` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, part, off = VH:SQLFetch (0)

				if tonumber (off) == 1 then
					VH:SQLQuery ("update `lua_feednews_cuts` set `off` = 0 where `part` = '" .. sql (part) .. "'")
					table.insert (cuts, part)
					back = "URL cut enabled: " .. part

				else
					back = "URL cut already enabled: " .. part
				end

			else
				back = "URL cut not found: " .. val
			end

		else -- list
			local _, rows = VH:SQLQuery ("select `part`, `off` from `lua_feednews_cuts`")

			if rows > 0 then
				back = "URL cut list:\r\n\r\n"

				for pos = 0, rows - 1 do
					local _, part, off = VH:SQLFetch (pos)
					back = back .. " " .. part .. " [" .. (tonumber (off) == 1 and "OFF" or "ON") .. "]\r\n"
				end

			else
				back = "URL cut list is empty."
			end
		end

	elseif data:match ("^.fn skip") then -- skip
		local name, val = data:match ("^.fn skip ([^ ]+) (.+)$")

		if name == "add" then -- add
			local safe = nmdc (val, true)
			local _, rows = VH:SQLQuery ("select `part` from `lua_feednews_skip` where `part` = '" .. sql (safe) .. "'")

			if rows == 0 then
				VH:SQLQuery ("insert into `lua_feednews_skip` (`part`) values ('" .. sql (safe) .. "')")
				table.insert (skip, safe)
				back = "Skip item added: " .. val

			else
				local _, part = VH:SQLFetch (0)
				back = "Skip item already exists: " .. part
			end

		elseif name == "del" then -- del
			local _, rows = VH:SQLQuery ("select `part` from `lua_feednews_skip` where `part` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, part = VH:SQLFetch (0)
				VH:SQLQuery ("delete from `lua_feednews_skip` where `part` = '" .. sql (part) .. "'")

				for pos, comp in pairs (skip) do
					if part == comp then
						table.remove (skip, pos)
						break
					end
				end

				back = "Skip item deleted: " .. part

			else
				back = "Skip item not found: " .. val
			end

		elseif name == "off" then -- off
			local _, rows = VH:SQLQuery ("select `part`, `off` from `lua_feednews_skip` where `part` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, part, off = VH:SQLFetch (0)

				if tonumber (off) == 0 then
					VH:SQLQuery ("update `lua_feednews_skip` set `off` = 1 where `part` = '" .. sql (part) .. "'")

					for pos, comp in pairs (skip) do
						if part == comp then
							table.remove (skip, pos)
							break
						end
					end

					back = "Skip item disabled: " .. part

				else
					back = "Skip item already disabled: " .. part
				end

			else
				back = "Skip item not found: " .. val
			end

		elseif name == "on" then -- on
			local _, rows = VH:SQLQuery ("select `part`, `off` from `lua_feednews_skip` where `part` = '" .. sql (nmdc (val, true)) .. "'")

			if rows > 0 then
				local _, part, off = VH:SQLFetch (0)

				if tonumber (off) == 1 then
					VH:SQLQuery ("update `lua_feednews_skip` set `off` = 0 where `part` = '" .. sql (part) .. "'")
					table.insert (skip, part)
					back = "Skip item enabled: " .. part

				else
					back = "Skip item already enabled: " .. part
				end

			else
				back = "Skip item not found: " .. val
			end

		else -- list
			local _, rows = VH:SQLQuery ("select `part`, `off` from `lua_feednews_skip`")

			if rows > 0 then
				back = "Skip item list:\r\n\r\n"

				for pos = 0, rows - 1 do
					local _, part, off = VH:SQLFetch (pos)
					back = back .. " " .. part .. " [" .. (tonumber (off) == 1 and "OFF" or "ON") .. "]\r\n"
				end

			else
				back = "Skip item list is empty."
			end
		end

	else -- unknown
		back = "Command list:\r\n\r\n"
		back = back .. " conf\t\t\t- Configuration list\r\n"
		back = back .. " conf <name> [conf]\t- Set configuration\r\n\r\n"

		back = back .. " lang\t\t\t- Translation list\r\n"
		back = back .. " lang <name> <lang>\t- Set translation\r\n\r\n"

		back = back .. " link\t\t\t- Feed link list\r\n"
		back = back .. " link add <name> <url>\t- Add feed link\r\n"
		back = back .. " link del <name>\t- Remove feed link\r\n"
		back = back .. " link off <name>\t- Disable feed link\r\n"
		back = back .. " link on <name>\t- Enable feed link\r\n\r\n"

		back = back .. " cuts\t\t\t- URL cut list\r\n"
		back = back .. " cuts add <lre>\t\t- Add URL cut\r\n"
		back = back .. " cuts del <lre>\t\t- Remove URL cut\r\n"
		back = back .. " cuts off <lre>\t\t- Disable URL cut\r\n"
		back = back .. " cuts on <lre>\t\t- Enable URL cut\r\n\r\n"

		back = back .. " skip\t\t\t- Skip item list\r\n"
		back = back .. " skip add <text>\t- Add skip item\r\n"
		back = back .. " skip del <text>\t\t- Remove skip item\r\n"
		back = back .. " skip off <text>\t\t- Disable skip item\r\n"
		back = back .. " skip on <text>\t\t- Enable skip item\r\n"
	end

	VH:SendToUser ("<" .. conf.nick .. "> " .. nmdc (back) .. "|", nick)
	return 0
end

function send (data, user, name, url, head, desc, more, auth, fcon, tcon)
	local back = variables (data, name, url, head, desc, more, auth, fcon, tcon)

	back = back:gsub ("&amp;", "&")
	back = back:gsub ("&#38;", "&")
	back = back:gsub ("&#x26;", "&")

	back = back:gsub ("&lt;", "<")
	back = back:gsub ("&#60;", "<")
	back = back:gsub ("&#x3[cC];", "<")

	back = back:gsub ("&gt;", ">")
	back = back:gsub ("&#62;", ">")
	back = back:gsub ("&#x3[eE];", ">")

	back = back:gsub ("&quot;", "\"")
	back = back:gsub ("&#34;", "\"")
	back = back:gsub ("&#x22;", "\"")

	back = back:gsub ("&#39;", "'")
	back = back:gsub ("&#x27;", "'")

	VH:SendToChat (conf.nick, nmdc (back), user, 10)
end

function variables (data, name, url, head, desc, more, auth, fcon, tcon)
	local back = _tostring (data)

	if name and # name > 0 then
		back = back:gsub ("<name>", escape (name))
	end

	if url and # url > 0 then
		back = back:gsub ("<link>", escape (url))
	end

	if head and # head > 0 then
		back = back:gsub ("<head>", escape (head))
	end

	if desc and # desc > 0 then
		back = back:gsub ("<desc>", escape (desc))
	end

	if more and # more > 0 then
		back = back:gsub ("<more>", escape (more))
	end

	if auth and # auth > 0 then
		back = back:gsub ("<auth>", escape (auth))
	end

	if fcon and # fcon > 0 then
		back = back:gsub ("<fcon>", escape (fcon))
	end

	if tcon and # tcon > 0 then
		back = back:gsub ("<tcon>", escape (tcon))
	end

	return back
end

function shuffle (list)
	local back = list
	local num, id = # back

	for pos = num, 2, -1 do
		id = math.random (pos)
		back [pos], back [id] = back [id], back [pos]
	end

	return back
end

function escape (data)
	local back = _tostring (data)
	back = back:gsub ("%%", "%%%%")
	return back
end

function sql (data)
	local back = _tostring (data)
	back = back:gsub (string.char (92), string.char (92, 92))
	back = back:gsub (string.char (34), string.char (92, 34))
	back = back:gsub (string.char (39), string.char (92, 39))
	return back
end

function nmdc (data, out)
	local back = _tostring (data)

	if out then
		back = back:gsub ("&amp;", "&") -- todo
		back = back:gsub ("&#36;", "$")
		back = back:gsub ("&#124;", "|")

	else
		back = back:gsub ("%$", "&#36;")
		back = back:gsub ("|", "&#124;")
	end

	return back
end

function decode (data)
	return data:gsub ("%%(%x%x)", function (hex) return string.char (tonumber (hex, 16)) end)
end

function _tostring (data)
	if type (data) == "number" then
		return string.format ("%d", data)
	end

	return tostring (data)
end

-- end of file