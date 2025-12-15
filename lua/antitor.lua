-- AntiTor 0.5.3.1
-- © 2011-2020 RoLex

conf = {
	updint = 60,											-- amount of minutes between automatic tor list updates
	mincls = 3,												-- minimum class to receive opchat notifications and access script commands
	skpcls = 2,												-- minimum class to skip ip check, only when allinf or oldver is enabled
	contmo = 15,											-- curl operation timeout in seconds, set higher for slow connections
	allinf = true,											-- show myinfo of connected user, false to disable
	updnot = false,											-- show notifications about successful tor list updates, false to disable
	oldver = false,											-- old verlihub version that doesnt support discardable connections
	sndrsn = false,											-- send reason to tor user before disconnect, only when allinf or oldver is enabled
	clrlst = false,											-- clear tor list before update, false to disable
	secbot = "",											-- security bot nick, leave empty to use hub nick
	opchat = "",											-- operator chat nick, leave empty to use hub nick
	torrsn = "Tor exits are blocked, use your real IP.",	-- block reason, only when allinf or oldver is enabled
	redadr = "",											-- redirect address for tor users, empty string to disable, only when allinf or oldver is enabled
	bantim = "",											-- ban time for tor users, empty string to disable, only when allinf or oldver is enabled
	banrsn = "Fuck off"										-- ban reason for tor users, only when allinf or oldver is enabled
}

lstchk = 0
torlst = {}

function Main (name)
	if os.execute ("curl -s --version > \"./curlinfo\" 2>&1") then
		local file = io.open ("./curlinfo", "r")

		if file then
			local line = file:read ("*line")
			file:close ()

			if line then
				local ver = line:match ("(%d+[%.%d]+)")

				if ver then
					VH:SendPMToAll ("AntiTor successfully loaded using cURL " .. ver .. ".", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
				else
					VH:SendPMToAll ("Unable to read cURL version, make sure it's installed on your system.", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
				end
			else
				-- should never happen
			end

			os.remove ("./curlinfo")
		else
			VH:SendPMToAll ("Unable to read cURL version, looks like local permission issue.", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
		end
	else
		VH:SendPMToAll ("Unable to execute OS command in order to read cURL version.", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
	end

	return 1
end

function UnLoad ()
	lstchk = nil
	torlst = nil
	conf = nil
	return 1
end

function VH_OnTimer (msec)
	if os.difftime (os.time (), lstchk) >= conf.updint * 60 then
		if os.execute ("curl -L --retry 3 --connect-timeout 5 -m " .. _tostring (conf.contmo) .. " -s -o \"./torlist\" \"http://ledo.feardc.net/mirror/torexit.list\"") then
			local file = io.open ("./torlist", "r")

			if file then
				local tor = {}
				file:close ()

				for line in io.lines ("./torlist") do
					if line:match ("^%d+%.%d+%.%d+%.%d+$") then
						table.insert (tor, line)
					end
				end

				if # tor == 0 then
					VH:SendPMToAll ("Unable to download Tor exit list, looks like remote server issue.", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
				else
					if conf.clrlst then
						torlst = {}
					end

					for _, addr in pairs (tor) do
						if getindex (addr) == 0 then
							table.insert (torlst, addr)
						end
					end

					if conf.updnot then
						VH:SendPMToAll ("Imported Tor exit list, using " .. _tostring (# torlst) .. " IPs.", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
					end
				end

				os.remove ("./torlist")
			else
				VH:SendPMToAll ("Unable to download Tor exit list, looks like local permission issue.", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
			end
		else
			VH:SendPMToAll ("Unable to execute OS command in order to download Tor exit list.", ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
		end

		lstchk = os.time ()
	end

	return 1
end

function VH_OnNewConn (addr)
	if not conf.oldver and not conf.allinf and getindex (addr) > 0 then
		VH:SendPMToAll ("Blocked Tor exit: " .. addr, ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
		return 0
	end

	return 1
end

function VH_OnHubCommand (nick, data, op, pm)
	if data:sub (2, 8) == "antitor" then
		local _, cls = VH:GetUserClass (nick)

		if cls and tonumber (cls) and tonumber (cls) >= conf.mincls then
			VH:SendDataToUser ("<" .. ((# conf.secbot ~= 0 and conf.secbot) or VH.HubSec) .. "> Tor exit list was updated on " .. os.date ("%d/%m %H:%M", lstchk) .. ", using " .. _tostring (# torlst) .. " IPs. Next update on " .. os.date ("%d/%m %H:%M", ((conf.updint * 60) + lstchk)) .. ".|", nick)
		else
			VH:SendDataToUser ("<" .. ((# conf.secbot ~= 0 and conf.secbot) or VH.HubSec) .. "> You don't have access to this command.|", nick)
		end

		return 0
	end

	return 1
end

function VH_OnUserLogin (nick, _addr)
	if conf.oldver or conf.allinf then
		local _, cls = VH:GetUserClass (nick)

		if cls and tonumber (cls) and tonumber (cls) < conf.skpcls then
			local _, addr = VH:GetUserIP (nick)

			if addr and # addr > 0 and getindex (addr) > 0 then
				if conf.allinf then
					local _, info = VH:GetMyINFO (nick)

					if info and # info > 0 then
						VH:SendPMToAll ("Blocked Tor exit from IP " .. addr .. ": " .. repchar (info), ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
					else
						VH:SendPMToAll ("Blocked Tor exit: " .. addr, ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
					end
				else
					VH:SendPMToAll ("Blocked Tor exit: " .. addr, ((# conf.opchat ~= 0 and conf.opchat) or VH.OpChat), conf.mincls, 10)
				end

				local data = ""

				if conf.sndrsn then
					data = data .. "<" .. ((# conf.secbot ~= 0 and conf.secbot) or VH.HubSec) .. "> " .. conf.torrsn .. "|"
				end

				if # conf.redadr > 0 then
					data = data .. "$ForceMove " .. conf.redadr .. "|"
				end

				if # data > 0 then
					VH:SendDataToUser (data, nick)
				end

				if # conf.bantim > 0 then
					data = ""

					if # conf.banrsn > 0 then
						data = data .. conf.banrsn .. " "
					end

					VH:KickUser (((# conf.secbot ~= 0 and conf.secbot) or VH.HubSec), nick, data .. "_ban_" .. conf.bantim)
				else
					VH:CloseConnection (nick)
				end

				return 0
			end
		end
	end

	return 1
end

function getindex (addr)
	for id, tor in pairs (torlst) do
		if tor == addr then
			return id
		end
	end

	return 0
end

function repchar (data)
	local back = data
	back = back:gsub ("%$", "&#36;")
	back = back:gsub ("|", "&#124;")

	for chr = 1, 31 do
		back = back:gsub (string.char (chr), "\\" .. _tostring (chr))
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