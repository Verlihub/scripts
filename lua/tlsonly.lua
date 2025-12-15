-- TLS Only 0.0.1.1
-- © 2021-2025 RoLex

conf = {
	isok = "This hub supports only TLS-encrypted connections, please update your favorites to: %s",
	nook = "This hub supports only TLS-encrypted connections, you will be redirected elsewhere: %s",
	move = {
		"hub.verlihub.net:7777",
		"piter.feardc.net"
	}
}

sets = {
	addr = ""
}

function Main (file)
	math.randomseed (os.time ())

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
	local _, clas = VH:GetUserClass (nick)

	if tonumber (clas) == -1 then
		return 1
	end

	local _, have = VH:IsSecConn (nick)

	if have then
		return 1
	end

	local _, have = VH:InUserSupports (nick, "TLS")

	if have then
		VH:DelNickTempBan (nick)
		return {"<" .. VH.HubSec .. "> " .. conf.isok:format (sets.addr) .. "|$ForceMove " .. sets.addr .. "|", 0, 0}
	end

	local move = conf.move [math.random (# conf.move)]
	return {"<" .. VH.HubSec .. "> " .. conf.nook:format (move) .. "|$ForceMove " .. move .. "|", 0, 0}
end

-- end of file