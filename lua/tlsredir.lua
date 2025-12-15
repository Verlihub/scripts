-- TLS Redirect 0.0.1.7
-- © 2019-2025 RoLex

conf = {
	text = "This hub supports TLS-encrypted connections, please update your favorites to: %s",
	wait = 3 * 60 * 60
}

sets = {
	addr = "",
	done = {},
	last = os.time ()
}

function Main (file)
	if # sets.addr > 0 then
		return 1
	end

	local _, addr = VH:GetConfig (VH.ConfName, "hub_host")
	sets.addr = "nmdcs://" .. addr

	if not addr:match (":%d+$") then
		sets.addr = sets.addr .. ":411"
	end

	return 1
end

function VH_OnUserInList (nick, addr)
	if not addr then
		return 1
	end

	local user = nick .. addr

	if sets.done [user] then
		return 1
	end

	local now = os.time ()
	local _, clas = VH:GetUserClass (nick)

	if tonumber (clas) == -1 then
		sets.done [user] = now
		return 1
	end

	local _, have = VH:IsSecConn (nick)

	if have then
		sets.done [user] = now
		return 1
	end

	local _, have = VH:InUserSupports (nick, "TLS")

	if have then
		sets.done [user] = now
		VH:DelNickTempBan (nick)
		return {"<" .. VH.HubSec .. "> " .. conf.text:format (sets.addr) .. "|$ForceMove " .. sets.addr .. "|", 0, 0}
	end

	return 1
end

function VH_OnTimer (msec)
	local now = os.time ()

	if os.difftime (now, sets.last) < 60 then
		return 1
	end

	for user, last in pairs (sets.done) do
		if os.difftime (now, last) >= conf.wait then
			sets.done [user] = nil
		end
	end

	sets.last = now
	return 1
end

-- end of file